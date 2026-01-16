import assert from "node:assert/strict";
import { before, describe, it } from "node:test";

import { network } from "hardhat";
import { encodePacked, keccak256, toHex, type Hex } from "viem";

describe("TensorHarness on-chain ops (viem)", async () => {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [walletClient] = await viem.getWalletClients();
  const owner = walletClient.account.address;

  const tensor = await viem.deployContract("TensorHarness");

  const waitFor = async (hash: Hex) => {
    await publicClient.waitForTransactionReceipt({ hash });
  };

  const tensorId = (seed: Hex, nonce: bigint) =>
    keccak256(
      encodePacked(
        ["string", "address", "bytes32", "uint64"],
        ["TENSOR", owner, seed, nonce]
      )
    );

  const seedA = `0x${"11".repeat(32)}` as Hex;
  const seedB = `0x${"22".repeat(32)}` as Hex;
  const seedAdd = `0x${"33".repeat(32)}` as Hex;
  const seedScale = `0x${"44".repeat(32)}` as Hex;
  const seedC = `0x${"55".repeat(32)}` as Hex;
  const seedD = `0x${"66".repeat(32)}` as Hex;
  const seedDot = `0x${"77".repeat(32)}` as Hex;
  const seedPayload = `0x${"88".repeat(32)}` as Hex;
  const seedPacked = `0x${"99".repeat(32)}` as Hex;

  const tensorAId = tensorId(seedA, 1n);
  const tensorBId = tensorId(seedB, 1n);
  const tensorCId = tensorId(seedC, 1n);
  const tensorDId = tensorId(seedD, 1n);
  const tensorPayloadId = tensorId(seedPayload, 1n);
  const tensorPackedId = tensorId(seedPacked, 1n);

  const setFlatValues = async (tensorIdValue: Hex, values: bigint[]) => {
    for (let i = 0; i < values.length; i++) {
      const hash = await tensor.write.set([tensorIdValue, BigInt(i), values[i]]);
      await waitFor(hash);
    }
  };

  before(async () => {
    const shape2x2 = [2n, 2n];
    const shape3 = [3n];

    await waitFor(await tensor.write.createTensor([2, shape2x2, seedA, 1n]));
    await waitFor(await tensor.write.createTensor([2, shape2x2, seedB, 1n]));

    await setFlatValues(tensorAId, [1n, 2n, 3n, 4n]);
    await setFlatValues(tensorBId, [4n, 3n, 2n, 1n]);

    await waitFor(await tensor.write.createTensor([1, shape3, seedC, 1n]));
    await waitFor(await tensor.write.createTensor([1, shape3, seedD, 1n]));

    await setFlatValues(tensorCId, [1n, 2n, 3n]);
    await setFlatValues(tensorDId, [4n, 5n, 6n]);
  });

  it("add(a, b) writes expected values", async () => {
    const hash = await tensor.write.add([tensorAId, tensorBId, seedAdd]);
    await waitFor(hash);

    const outId = tensorId(seedAdd, 1n);
    const got = [];
    for (let i = 0; i < 4; i++) {
      got.push(await tensor.read.get([outId, BigInt(i)]));
    }

    assert.deepStrictEqual(got, [5n, 5n, 5n, 5n]);
  });

  it("scale(a, s) writes expected values", async () => {
    const hash = await tensor.write.scale([tensorAId, 3n, seedScale]);
    await waitFor(hash);

    const outId = tensorId(seedScale, 1n);
    const got = [];
    for (let i = 0; i < 4; i++) {
      got.push(await tensor.read.get([outId, BigInt(i)]));
    }

    assert.deepStrictEqual(got, [3n, 6n, 9n, 12n]);
  });

  it("dot(c, d) writes expected scalar", async () => {
    const hash = await tensor.write.dot([tensorCId, tensorDId, seedDot]);
    await waitFor(hash);

    const outId = tensorId(seedDot, 1n);
    const got = await tensor.read.get([outId, 0n]);

    assert.equal(got, 32n);
  });

  it("payload backend matches slot reads and capsule hash", async () => {
    const shape2x2 = [2n, 2n];
    const values = [1n, 2n, 3n, 4n];

    await waitFor(
      await tensor.write.createTensor([2, shape2x2, seedPayload, 1n])
    );

    const keys = values.map((_, i) => ({
      id: tensorPayloadId,
      flatIndex: BigInt(i),
    }));

    await waitFor(await tensor.write.batchSet([keys, values]));
    const rootSlot = await tensor.read.freezeTensor([tensorPayloadId]);

    const payload = encodePacked(["int256[]"], [values]);
    await waitFor(await tensor.write.writeTensor([tensorPayloadId, payload]));

    const got = [];
    for (let i = 0; i < values.length; i++) {
      got.push(await tensor.read.get([tensorPayloadId, BigInt(i)]));
    }
    assert.deepStrictEqual(got, values);

    const gotBatch = await tensor.read.batchGet([keys]);
    assert.deepStrictEqual(gotBatch, values);

    const rootPayload = await tensor.read.freezeTensor([tensorPayloadId]);
    assert.equal(rootPayload, rootSlot);
  });

  it("packed uint8 backend is used for reads and capsule hashing", async () => {
    const shape2x2 = [2n, 2n];
    const slotValues = [1n, 2n, 3n, 4n];
    const packedValues = [9, 8, 7, 6];
    const packedValuesBig = packedValues.map((value) => BigInt(value));

    await waitFor(
      await tensor.write.createTensor([2, shape2x2, seedPacked, 1n])
    );

    const keys = slotValues.map((_, i) => ({
      id: tensorPackedId,
      flatIndex: BigInt(i),
    }));

    await waitFor(await tensor.write.batchSet([keys, slotValues]));
    const rootSlot = await tensor.read.freezeTensor([tensorPackedId]);

    const payload = toHex(Uint8Array.from(packedValues));
    await waitFor(await tensor.write.writePackedU8([tensorPackedId, payload]));

    const got = [];
    for (let i = 0; i < packedValues.length; i++) {
      got.push(await tensor.read.get([tensorPackedId, BigInt(i)]));
    }
    assert.deepStrictEqual(got, packedValuesBig);

    const gotBatch = await tensor.read.batchGet([keys]);
    assert.deepStrictEqual(gotBatch, packedValuesBig);

    const rootPacked = await tensor.read.freezeTensor([tensorPackedId]);
    assert.notEqual(rootPacked, rootSlot);
  });
});
