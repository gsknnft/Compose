import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

import { network } from "hardhat";
import { encodePacked, formatEther, keccak256, toHex, type Hex } from "viem";

type BenchMode = "single" | "chunked" | "payload" | "packed";
type BenchStatus = "ok" | "failed";

type BenchRow = {
  op: string;
  size: string;
  mode: BenchMode;
  elements: number;
  density?: number;
  chunks?: number;
  gas?: bigint;
  gasPerElement?: number;
  ethCost?: number;
  usdCost?: number;
  status: BenchStatus;
};

export default async function main() {
  //@ts-expect-error
const { viem } = await network.connect();
const publicClient = await viem.getPublicClient();
const [walletClient] = await viem.getWalletClients();
const owner = walletClient.account.address;

const GAS_PRICE_GWEI = BigInt(process.env.GAS_PRICE_GWEI ?? "20");
const ETH_PRICE_USD = Number(process.env.ETH_PRICE_USD ?? "3000");
const GAS_PRICE_WEI = GAS_PRICE_GWEI * 1_000_000_000n;
const BATCH_CHUNK = Number(process.env.BATCH_CHUNK ?? "256");
const OUTPUT_DIR = process.env.BENCH_OUT_DIR ?? "scripts/benchmarks/output";
const OUTPUT_BASENAME = process.env.BENCH_BASENAME ?? "tensorMathGas";

const tensor = await viem.deployContract("TensorHarness");
const payloadChunkBytes = Number(await tensor.read.payloadChunkBytes());
const results: BenchRow[] = [];

const waitFor = async (hash: Hex) => {
  await publicClient.waitForTransactionReceipt({ hash });
};

const seedFor = (label: string) =>
  keccak256(encodePacked(["string"], [label])) as Hex;

const tensorId = (seed: Hex, nonce: bigint) =>
  keccak256(
    encodePacked(
      ["string", "address", "bytes32", "uint64"],
      ["TENSOR", owner, seed, nonce]
    )
  );

const buildKeys = (tensorIdValue: Hex, count: number) =>
  Array.from({ length: count }, (_, i) => ({
    id: tensorIdValue,
    flatIndex: BigInt(i),
  }));

const buildKeysForIndices = (tensorIdValue: Hex, indices: number[]) =>
  indices.map((index) => ({
    id: tensorIdValue,
    flatIndex: BigInt(index),
  }));

const fillValues = (count: number) =>
  Array.from({ length: count }, (_, i) => BigInt(i + 1));

const fillU8Values = (count: number) =>
  Array.from({ length: count }, (_, i) => i & 0xff);

const payloadForValues = (values: bigint[]) =>
  encodePacked(["int256[]"], [values]);

const payloadChunkCount = (elements: number) => {
  if (elements === 0) return 0;
  return Math.ceil((elements * 32) / payloadChunkBytes);
};

const packedWordCount = (elements: number) => {
  if (elements === 0) return 0;
  return Math.ceil(elements / 32);
};

const formatCost = (gas: bigint) => {
  const wei = gas * GAS_PRICE_WEI;
  const eth = Number(formatEther(wei));
  const usd = eth * ETH_PRICE_USD;
  return { eth, usd };
};

const logGas = (label: string, gas: bigint, perElement?: number) => {
  const per =
    perElement !== undefined ? ` (~${perElement.toFixed(0)} gas/elem)` : "";
  const cost = formatCost(gas);
  console.log(
    `${label}: ${gas.toString()}${per} | ${cost.eth.toFixed(6)} ETH (~$${cost.usd.toFixed(2)})`
  );
};

const recordResult = (row: BenchRow, label: string) => {
  if (row.status === "ok" && row.gas !== undefined) {
    logGas(label, row.gas, row.gasPerElement);
  } else {
    console.log(`${label}: exceeds block gas limit (estimate failed)`);
  }
  results.push(row);
};

const tryEstimate = async (params: {
  label: string;
  op: string;
  size: string;
  mode: BenchMode;
  elements: number;
  density?: number;
  chunks?: number;
  estimate: () => Promise<bigint>;
}) => {
  try {
    const gas = await params.estimate();
    const gasPerElement = params.elements
      ? Number(gas) / params.elements
      : undefined;
    const cost = formatCost(gas);
    recordResult(
      {
        op: params.op,
        size: params.size,
        mode: params.mode,
        elements: params.elements,
        density: params.density,
        chunks: params.chunks,
        gas,
        gasPerElement,
        ethCost: cost.eth,
        usdCost: cost.usd,
        status: "ok",
      },
      params.label
    );
    return gas;
  } catch {
    recordResult(
      {
        op: params.op,
        size: params.size,
        mode: params.mode,
        elements: params.elements,
        density: params.density,
        chunks: params.chunks,
        status: "failed",
      },
      params.label
    );
    return null;
  }
};

const chunkArray = <T>(arr: T[], size: number): T[][] => {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
};

const createTensor = async (
  rank: number,
  shape: bigint[],
  seedLabel: string
) => {
  const seed = seedFor(seedLabel);
  await waitFor(await tensor.write.createTensor([rank, shape, seed, 1n]));
  return { id: tensorId(seed, 1n), seed };
};

const batchSetValuesWithKeys = async (
  keys: { id: Hex; flatIndex: bigint }[],
  values: bigint[]
) => {
  const keyChunks = chunkArray(keys, BATCH_CHUNK);
  const valueChunks = chunkArray(values, BATCH_CHUNK);

  for (let i = 0; i < keyChunks.length; i++) {
    await waitFor(await tensor.write.batchSet([keyChunks[i], valueChunks[i]]));
  }
};

const batchSetValues = async (tensorIdValue: Hex, values: bigint[]) => {
  const keys = buildKeys(tensorIdValue, values.length);
  await batchSetValuesWithKeys(keys, values);
};

const estimateBatchSetSingle = async (
  keys: { id: Hex; flatIndex: bigint }[],
  values: bigint[]
) => {
  return publicClient.estimateContractGas({
    address: tensor.address,
    abi: tensor.abi,
    functionName: "batchSet",
    args: [keys, values],
    account: owner,
  });
};

const estimateBatchSetChunked = async (
  keys: { id: Hex; flatIndex: bigint }[],
  values: bigint[]
) => {
  const keyChunks = chunkArray(keys, BATCH_CHUNK);
  const valueChunks = chunkArray(values, BATCH_CHUNK);
  let total = 0n;

  for (let i = 0; i < keyChunks.length; i++) {
    const gas = await publicClient.estimateContractGas({
      address: tensor.address,
      abi: tensor.abi,
      functionName: "batchSet",
      args: [keyChunks[i], valueChunks[i]],
      account: owner,
    });
    total += gas;
  }

  return total;
};

const estimateBatchGetSingle = async (
  keys: { id: Hex; flatIndex: bigint }[]
) => {
  return publicClient.estimateContractGas({
    address: tensor.address,
    abi: tensor.abi,
    functionName: "batchGet",
    args: [keys],
    account: owner,
  });
};

const estimateBatchGetChunked = async (
  keys: { id: Hex; flatIndex: bigint }[]
) => {
  const keyChunks = chunkArray(keys, BATCH_CHUNK);
  let total = 0n;

  for (const chunk of keyChunks) {
    const gas = await publicClient.estimateContractGas({
      address: tensor.address,
      abi: tensor.abi,
      functionName: "batchGet",
      args: [chunk],
      account: owner,
    });
    total += gas;
  }

  return total;
};

const estimateWriteTensor = async (
  tensorIdValue: Hex,
  payload: Hex
) => {
  return publicClient.estimateContractGas({
    address: tensor.address,
    abi: tensor.abi,
    functionName: "writeTensor",
    args: [tensorIdValue, payload],
    account: owner,
  });
};

const estimateReadTensor = async (tensorIdValue: Hex) => {
  return publicClient.estimateContractGas({
    address: tensor.address,
    abi: tensor.abi,
    functionName: "readTensor",
    args: [tensorIdValue],
    account: owner,
  });
};

const estimateWritePackedU8 = async (
  tensorIdValue: Hex,
  payload: Hex
) => {
  return publicClient.estimateContractGas({
    address: tensor.address,
    abi: tensor.abi,
    functionName: "writePackedU8",
    args: [tensorIdValue, payload],
    account: owner,
  });
};

const estimateReadPackedU8 = async (tensorIdValue: Hex) => {
  return publicClient.estimateContractGas({
    address: tensor.address,
    abi: tensor.abi,
    functionName: "readPackedU8",
    args: [tensorIdValue],
    account: owner,
  });
};

const sparseIndices = (total: number, density: number) => {
  const step = Math.max(1, Math.floor(1 / density));
  const indices: number[] = [];
  for (let i = 0; i < total; i += step) {
    indices.push(i);
  }
  return indices;
};

console.log("TensorMath gas estimates (TensorHarness)");
console.log(
  `Assumptions: ${GAS_PRICE_GWEI.toString()} gwei, $${ETH_PRICE_USD} / ETH, batch chunk ${BATCH_CHUNK}`
);

const matrixSizes = [2, 4, 8, 16, 32];
const vectorSizes = [3, 8, 16, 32];
const sparseDensities = [0.01, 0.05, 0.1];
const sparseMatrixSize = 32;

for (const size of matrixSizes) {
  const shape = [BigInt(size), BigInt(size)];
  const count = size * size;
  const valuesA = fillValues(count);
  const valuesB = fillValues(count).reverse();
  const sizeLabel = `${size}x${size}`;

  const { id: aId } = await createTensor(2, shape, `matrix-${size}-a`);
  const { id: bId } = await createTensor(2, shape, `matrix-${size}-b`);

  const denseKeys = buildKeys(aId, count);

  await tryEstimate({
    label: `batchSet(${sizeLabel}) [single]`,
    op: "batchSet",
    size: sizeLabel,
    mode: "single",
    elements: count,
    estimate: () => estimateBatchSetSingle(denseKeys, valuesA),
  });

  const batchSetChunks = Math.ceil(valuesA.length / BATCH_CHUNK);
  await tryEstimate({
    label: `batchSet(${sizeLabel}) [chunked]`,
    op: "batchSet",
    size: sizeLabel,
    mode: "chunked",
    elements: count,
    chunks: batchSetChunks,
    estimate: () => estimateBatchSetChunked(denseKeys, valuesA),
  });

  await batchSetValuesWithKeys(denseKeys, valuesA);
  await batchSetValues(bId, valuesB);

  await tryEstimate({
    label: `batchGet(${sizeLabel}) [single]`,
    op: "batchGet",
    size: sizeLabel,
    mode: "single",
    elements: count,
    estimate: () => estimateBatchGetSingle(denseKeys),
  });

  const batchGetChunks = Math.ceil(count / BATCH_CHUNK);
  await tryEstimate({
    label: `batchGet(${sizeLabel}) [chunked]`,
    op: "batchGet",
    size: sizeLabel,
    mode: "chunked",
    elements: count,
    chunks: batchGetChunks,
    estimate: () => estimateBatchGetChunked(denseKeys),
  });

  const { id: payloadId } = await createTensor(
    2,
    shape,
    `matrix-${size}-payload`
  );
  const payload = payloadForValues(valuesA);
  const payloadChunks = payloadChunkCount(count);

  const payloadWriteGas = await tryEstimate({
    label: `writeTensor(${sizeLabel}) [payload]`,
    op: "writeTensor",
    size: sizeLabel,
    mode: "payload",
    elements: count,
    chunks: payloadChunks,
    estimate: () => estimateWriteTensor(payloadId, payload),
  });

  if (payloadWriteGas !== null) {
    await waitFor(await tensor.write.writeTensor([payloadId, payload]));

    await tryEstimate({
      label: `readTensor(${sizeLabel}) [payload]`,
      op: "readTensor",
      size: sizeLabel,
      mode: "payload",
      elements: count,
      chunks: payloadChunks,
      estimate: () => estimateReadTensor(payloadId),
    });
  }

  const { id: packedId } = await createTensor(
    2,
    shape,
    `matrix-${size}-packed`
  );
  const packedValues = fillU8Values(count);
  const packedPayload = toHex(Uint8Array.from(packedValues));
  const packedWords = packedWordCount(count);

  const packedWriteGas = await tryEstimate({
    label: `writePackedU8(${sizeLabel}) [packed]`,
    op: "writePackedU8",
    size: sizeLabel,
    mode: "packed",
    elements: count,
    chunks: packedWords,
    estimate: () => estimateWritePackedU8(packedId, packedPayload),
  });

  if (packedWriteGas !== null) {
    await waitFor(await tensor.write.writePackedU8([packedId, packedPayload]));

    await tryEstimate({
      label: `readPackedU8(${sizeLabel}) [packed]`,
      op: "readPackedU8",
      size: sizeLabel,
      mode: "packed",
      elements: count,
      chunks: packedWords,
      estimate: () => estimateReadPackedU8(packedId),
    });
  }

  const seedAdd = seedFor(`add-${size}`);
  const seedScale = seedFor(`scale-${size}`);

  await tryEstimate({
    label: `add(${sizeLabel})`,
    op: "add",
    size: sizeLabel,
    mode: "single",
    elements: count,
    estimate: () =>
      publicClient.estimateContractGas({
        address: tensor.address,
        abi: tensor.abi,
        functionName: "add",
        args: [aId, bId, seedAdd],
        account: owner,
      }),
  });

  await tryEstimate({
    label: `scale(${sizeLabel}, s=3)`,
    op: "scale",
    size: sizeLabel,
    mode: "single",
    elements: count,
    estimate: () =>
      publicClient.estimateContractGas({
        address: tensor.address,
        abi: tensor.abi,
        functionName: "scale",
        args: [aId, 3n, seedScale],
        account: owner,
      }),
  });
}

for (const size of vectorSizes) {
  const shape = [BigInt(size)];
  const valuesA = fillValues(size);
  const valuesB = fillValues(size).reverse();
  const sizeLabel = `1x${size}`;

  const { id: aId } = await createTensor(1, shape, `vector-${size}-a`);
  const { id: bId } = await createTensor(1, shape, `vector-${size}-b`);

  const denseKeys = buildKeys(aId, size);

  await tryEstimate({
    label: `batchSet(${sizeLabel}) [single]`,
    op: "batchSet",
    size: sizeLabel,
    mode: "single",
    elements: size,
    estimate: () => estimateBatchSetSingle(denseKeys, valuesA),
  });

  const batchSetChunks = Math.ceil(valuesA.length / BATCH_CHUNK);
  await tryEstimate({
    label: `batchSet(${sizeLabel}) [chunked]`,
    op: "batchSet",
    size: sizeLabel,
    mode: "chunked",
    elements: size,
    chunks: batchSetChunks,
    estimate: () => estimateBatchSetChunked(denseKeys, valuesA),
  });

  await batchSetValuesWithKeys(denseKeys, valuesA);
  await batchSetValues(bId, valuesB);

  await tryEstimate({
    label: `batchGet(${sizeLabel}) [single]`,
    op: "batchGet",
    size: sizeLabel,
    mode: "single",
    elements: size,
    estimate: () => estimateBatchGetSingle(denseKeys),
  });

  const batchGetChunks = Math.ceil(size / BATCH_CHUNK);
  await tryEstimate({
    label: `batchGet(${sizeLabel}) [chunked]`,
    op: "batchGet",
    size: sizeLabel,
    mode: "chunked",
    elements: size,
    chunks: batchGetChunks,
    estimate: () => estimateBatchGetChunked(denseKeys),
  });

  const { id: payloadId } = await createTensor(
    1,
    shape,
    `vector-${size}-payload`
  );
  const payload = payloadForValues(valuesA);
  const payloadChunks = payloadChunkCount(size);

  const payloadWriteGas = await tryEstimate({
    label: `writeTensor(${sizeLabel}) [payload]`,
    op: "writeTensor",
    size: sizeLabel,
    mode: "payload",
    elements: size,
    chunks: payloadChunks,
    estimate: () => estimateWriteTensor(payloadId, payload),
  });

  if (payloadWriteGas !== null) {
    await waitFor(await tensor.write.writeTensor([payloadId, payload]));

    await tryEstimate({
      label: `readTensor(${sizeLabel}) [payload]`,
      op: "readTensor",
      size: sizeLabel,
      mode: "payload",
      elements: size,
      chunks: payloadChunks,
      estimate: () => estimateReadTensor(payloadId),
    });
  }

  const { id: packedId } = await createTensor(
    1,
    shape,
    `vector-${size}-packed`
  );
  const packedValues = fillU8Values(size);
  const packedPayload = toHex(Uint8Array.from(packedValues));
  const packedWords = packedWordCount(size);

  const packedWriteGas = await tryEstimate({
    label: `writePackedU8(${sizeLabel}) [packed]`,
    op: "writePackedU8",
    size: sizeLabel,
    mode: "packed",
    elements: size,
    chunks: packedWords,
    estimate: () => estimateWritePackedU8(packedId, packedPayload),
  });

  if (packedWriteGas !== null) {
    await waitFor(await tensor.write.writePackedU8([packedId, packedPayload]));

    await tryEstimate({
      label: `readPackedU8(${sizeLabel}) [packed]`,
      op: "readPackedU8",
      size: sizeLabel,
      mode: "packed",
      elements: size,
      chunks: packedWords,
      estimate: () => estimateReadPackedU8(packedId),
    });
  }

  const seedDot = seedFor(`dot-${size}`);
  await tryEstimate({
    label: `dot(${sizeLabel})`,
    op: "dot",
    size: sizeLabel,
    mode: "single",
    elements: size,
    estimate: () =>
      publicClient.estimateContractGas({
        address: tensor.address,
        abi: tensor.abi,
        functionName: "dot",
        args: [aId, bId, seedDot],
        account: owner,
      }),
  });
}

const sparseTotal = sparseMatrixSize * sparseMatrixSize;
const sparseShape = [BigInt(sparseMatrixSize), BigInt(sparseMatrixSize)];
const sparseSizeLabel = `${sparseMatrixSize}x${sparseMatrixSize}`;

for (const density of sparseDensities) {
  const indices = sparseIndices(sparseTotal, density);
  const values = indices.map((index) => BigInt(index + 1));
  const densityLabel = `${Math.round(density * 100)}%`;

  const { id: sparseId } = await createTensor(
    2,
    sparseShape,
    `matrix-${sparseMatrixSize}-sparse-${densityLabel}`
  );

  const sparseKeys = buildKeysForIndices(sparseId, indices);
  const sparseChunks = Math.ceil(sparseKeys.length / BATCH_CHUNK);

  await tryEstimate({
    label: `batchSet(${sparseSizeLabel}) [single, sparse ${densityLabel}]`,
    op: "batchSet",
    size: sparseSizeLabel,
    mode: "single",
    elements: sparseKeys.length,
    density,
    estimate: () => estimateBatchSetSingle(sparseKeys, values),
  });

  await tryEstimate({
    label: `batchSet(${sparseSizeLabel}) [chunked, sparse ${densityLabel}]`,
    op: "batchSet",
    size: sparseSizeLabel,
    mode: "chunked",
    elements: sparseKeys.length,
    density,
    chunks: sparseChunks,
    estimate: () => estimateBatchSetChunked(sparseKeys, values),
  });

  await tryEstimate({
    label: `batchGet(${sparseSizeLabel}) [single, sparse ${densityLabel}]`,
    op: "batchGet",
    size: sparseSizeLabel,
    mode: "single",
    elements: sparseKeys.length,
    density,
    estimate: () => estimateBatchGetSingle(sparseKeys),
  });

  await tryEstimate({
    label: `batchGet(${sparseSizeLabel}) [chunked, sparse ${densityLabel}]`,
    op: "batchGet",
    size: sparseSizeLabel,
    mode: "chunked",
    elements: sparseKeys.length,
    density,
    chunks: sparseChunks,
    estimate: () => estimateBatchGetChunked(sparseKeys),
  });
}

const outDir = path.resolve(OUTPUT_DIR);
await mkdir(outDir, { recursive: true });

const csvHeader =
  "op,size,mode,elements,density,chunks,status,gas,gas_per_element,eth_cost,usd_cost";
const csvLines = [
  csvHeader,
  ...results.map((row) => {
    const gas = row.gas?.toString() ?? "";
    const gasPerElement =
      row.gasPerElement !== undefined
        ? row.gasPerElement.toFixed(0)
        : "";
    const eth = row.ethCost !== undefined ? row.ethCost.toFixed(6) : "";
    const usd = row.usdCost !== undefined ? row.usdCost.toFixed(2) : "";
    const chunks = row.chunks !== undefined ? row.chunks.toString() : "";
    const density =
      row.density !== undefined ? row.density.toFixed(2) : "";
    return [
      row.op,
      row.size,
      row.mode,
      row.elements.toString(),
      density,
      chunks,
      row.status,
      gas,
      gasPerElement,
      eth,
      usd,
    ].join(",");
  }),
];

const mdLines = [
  "# TensorMath Bench",
  "",
  `Assumptions: ${GAS_PRICE_GWEI.toString()} gwei, $${ETH_PRICE_USD} / ETH, batch chunk ${BATCH_CHUNK}`,
  "",
  "| op | size | mode | elements | density | chunks | status | gas | gas/elem | eth | usd |",
  "| --- | --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: |",
  ...results.map((row) => {
    const gas = row.gas?.toString() ?? "-";
    const gasPerElement =
      row.gasPerElement !== undefined
        ? row.gasPerElement.toFixed(0)
        : "-";
    const eth = row.ethCost !== undefined ? row.ethCost.toFixed(6) : "-";
    const usd = row.usdCost !== undefined ? row.usdCost.toFixed(2) : "-";
    const chunks = row.chunks !== undefined ? row.chunks.toString() : "-";
    const density =
      row.density !== undefined ? row.density.toFixed(2) : "-";
    return `| ${row.op} | ${row.size} | ${row.mode} | ${row.elements} | ${density} | ${chunks} | ${row.status} | ${gas} | ${gasPerElement} | ${eth} | ${usd} |`;
  }),
];

const csvPath = path.join(outDir, `${OUTPUT_BASENAME}.csv`);
const mdPath = path.join(outDir, `${OUTPUT_BASENAME}.md`);

await writeFile(csvPath, `${csvLines.join("\n")}\n`);
await writeFile(mdPath, `${mdLines.join("\n")}\n`);

console.log(`Wrote benchmark output to ${csvPath} and ${mdPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});