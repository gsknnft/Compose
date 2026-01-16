---
eip: XXXX
title: Modular Tensor Memory and Capsules for EVM (Diamond Native)
description: Standard for on-chain tensor memory, deterministic computation, and capsule commitments using ERC-2535 Diamonds.
author: G
discussions-to: <TBD>
status: Draft
type: Standards Track
category: ERC
created: 2026-01-15
requires: 2535
---

## Abstract

This EIP defines on-chain tensor memory, deterministic tensor operations, and
verifiable capsule commitments using ERC-2535 Diamonds. It standardizes tensor
metadata, indexing, ownership, and provenance while keeping storage backends
pluggable.

## Motivation

Smart contracts lack persistent structured memory, deterministic computation
graphs, and portable state verification. NFTs today act as receipts to external
data; they do not own state. This proposal treats tokens as containers: tensor
state is first-class, addressable, and computable on-chain, with provenance
anchored by capsules.

## Specification

### Core Concepts

- Tensor: multi-dimensional structured memory with deterministic identifiers
  derived from (owner, seed, nonce).
- Capsule: cryptographic commitment to frozen tensor state.
- Facets: manager, read, write, batch, math, capsule, registry, NFT binding.

### Tensor Identifier

Implementations MUST derive tensor identifiers deterministically:

```
tensorId = keccak256("TENSOR", owner, seed, nonce)
```

### Storage Layout

All state MUST be stored in a single Diamond storage namespace:

```
keccak256("diamond.tensor.core.storage.v1")
```

Implementations MUST use append-only storage evolution and MUST NOT overlap
tensor, capsule, or lineage storage.

### Tensor Metadata

Tensor metadata MUST include:

- id (bytes32)
- owner (address)
- rank and shape
- total size (product of shape)
- creation timestamp
- flags (uint32) for dtype/semantic/encoding hints

### Tensor Data

The canonical dense backend uses flat index addressing:

```
mapping(bytes32 => mapping(uint256 => int256))
```

### Struct Types (Reference)

The following structs are used by the interfaces below and mirror the
implementation in `TensorStorage.sol`:

```solidity
library TensorStorage {
    struct TensorKey {
        bytes32 id;
        uint256 flatIndex;
    }

    struct TensorMeta {
        bytes32 id;
        address owner;
        uint8 rank;
        uint256[] shape;
        uint256 size;
        uint64 createdAt;
        uint32 flags;
        uint128 reserved;
    }

    struct CapsuleRecord {
        bytes32 capsuleRoot;
        uint64 timestamp;
        address owner;
    }

    struct NFTBinding {
        address nft;
        uint256 tokenId;
        bytes32 tensorId;
        bool immutableBinding;
        uint64 boundAt;
    }
}
```

### Facet Interfaces (Normative)

The following interfaces match the current implementation signatures.

```solidity
interface TensorManagerFacet {
    function createTensor(
        uint8 rank,
        uint256[] calldata shape,
        bytes32 seed,
        uint64 nonce
    ) external returns (bytes32 tensorId);

    function destroyTensor(bytes32 tensorId) external;
}

interface TensorReadFacet {
    function meta(bytes32 tensorId)
        external
        view
        returns (TensorStorage.TensorMeta memory);

    function get(bytes32 tensorId, uint256 flatIndex)
        external
        view
        returns (int256);

    function getAt(bytes32 tensorId, uint256[] calldata indices)
        external
        view
        returns (int256);
}

interface TensorWriteFacet {
    function set(bytes32 tensorId, uint256 flatIndex, int256 value) external;
    function setAt(
        bytes32 tensorId,
        uint256[] calldata indices,
        int256 value
    ) external;
}

interface TensorBatchFacet {
    function batchSet(
        TensorStorage.TensorKey[] calldata keys,
        int256[] calldata values
    ) external;

    function batchGet(TensorStorage.TensorKey[] calldata keys)
        external
        view
        returns (int256[] memory values);
}

interface TensorMathFacet {
    function add(bytes32 a, bytes32 b, bytes32 seed)
        external
        returns (bytes32 out);

    function scale(bytes32 a, int256 scalar, bytes32 seed)
        external
        returns (bytes32 out);

    function dot(bytes32 a, bytes32 b, bytes32 seed)
        external
        returns (bytes32 out);
}

interface CapsuleFacet {
    function freezeTensor(bytes32 tensorId)
        external
        view
        returns (bytes32 capsuleRoot);

    function emitCapsule(bytes32 tensorId) external returns (bytes32 root);
}

interface CapsuleRegistryFacet {
    function registerCapsule(bytes32 tensorId, bytes32 capsuleRoot) external;

    function capsuleCount(bytes32 tensorId)
        external
        view
        returns (uint256);

    function capsuleAt(bytes32 tensorId, uint256 index)
        external
        view
        returns (TensorStorage.CapsuleRecord memory);

    function latestCapsule(bytes32 tensorId)
        external
        view
        returns (TensorStorage.CapsuleRecord memory);
}

interface NFTBindingFacet {
    function bindNFT(
        address nft,
        uint256 tokenId,
        bytes32 tensorId,
        bool immutableBinding
    ) external;

    function rebindNFT(
        address nft,
        uint256 tokenId,
        bytes32 newTensorId
    ) external;

    function unbindNFT(address nft, uint256 tokenId) external;

    function getBinding(address nft, uint256 tokenId)
        external
        view
        returns (TensorStorage.NFTBinding memory);

    function tensorOf(address nft, uint256 tokenId)
        external
        view
        returns (bytes32);
}
```

### Ownership and Mutation

All mutation and capsule registration operations MUST enforce tensor ownership
prior to state changes.

NFT-bound tensors MUST derive authority from the NFT owner at call time.
External ownership checks MUST be treated as potentially adversarial.

### Capsule Provenance

Capsules are append-only. Once registered, a capsule root MUST NOT be modified
or removed. Each registry entry MUST include capsule root, timestamp, and owner.

If an implementation stores capsule history as a Merkle structure, the
append-only rule MUST apply to the Merkle leaves, and the Merkle root MUST be
updated monotonically to reflect new leaves. Historical roots MUST remain
derivable from the leaf set and MUST be verifiable against emitted events. A
reorg-safe design SHOULD emit the new Merkle root alongside the capsule root so
light clients can verify membership.

Non-normative guidance: Merkle provenance is intended for proofs over capsule
entries or chunk manifests, not for bulk dense payloads on L1. Implementations
MAY define leaf formats and ordering, but they MUST be deterministic and
append-only for proofs to be meaningful.

### Flags

The flags field uses a 32-bit bitfield:

- bits 0-7: base dtype (int8, int16, int32, float16, etc)
- bits 8-15: semantic hint (image, audio, mesh, weights)
- bits 16-23: encoding (raw, RLE, LZ, custom)
- bits 24-31: reserved

### Encodings and Lazy Validation

Implementations that accept encoded payloads MUST NOT parse or validate payloads
during writes. Reads MAY revert on invalid or inconsistent payloads.
Implementations MUST hash payloads using a canonical byte representation
(including deterministic padding rules) when computing capsule roots.

### Upgradeability

1. Storage layout MUST be append-only.
2. No field may be reordered or removed.
3. New fields MAY be appended.
4. Logic changes MUST be introduced via new facets.
5. Existing facets MUST NOT reinterpret existing storage fields.

### Optional Extensions (Non-Normative)

Backends MAY be provided for alternative payload storage, including:

- in-slot storage for small tensors
- bytecode payloads (SSTORE2-style)
- calldata-backed payloads (ephemeral)
- external DA backends

Backend choice MUST NOT change tensor semantics.
For any given tensor, at most one backend MAY be authoritative for writes at a
time. Once a payload backend is attached, slot-based writes MUST be rejected.

The following optional interfaces match the reference implementation:

```solidity
interface ITensorBackend {
    function writeTensor(bytes32 tensorId, bytes calldata payload) external;
    function readTensor(bytes32 tensorId) external view returns (bytes memory);
    function readAt(
        bytes32 tensorId,
        uint256 offset,
        uint256 length
    ) external view returns (bytes memory);
}

interface TensorSSTORE2Facet is ITensorBackend {
    function payloadChunkCount(bytes32 tensorId)
        external
        view
        returns (uint256);

    function payloadChunkAt(bytes32 tensorId, uint256 index)
        external
        view
        returns (address);

    function payloadChunkBytes() external pure returns (uint256);
}

interface TensorPackedU8Facet {
    function writePackedU8(bytes32 tensorId, bytes calldata payload) external;
    function readPackedU8(bytes32 tensorId) external view returns (bytes memory);
    function packedU8WordCount(bytes32 tensorId)
        external
        view
        returns (uint256);
}
```

## Rationale

- Tokens as containers: tensor state is on-chain and deterministic, not a URI.
- Diamond facets: modularity enables separate lifecycle, IO, math, and provenance.
- Flags over strings: compact, deterministic metadata avoids storage overhead.
- Backends are optional: semantics are stable while storage evolves.

## Backwards Compatibility

This EIP introduces new interfaces and storage layouts and does not break
existing contracts. No backward compatibility issues are expected.

## Reference Implementation

Reference contracts are available in:

- `packages/adapters/evm/contracts/DiamondTensors`
- `packages/adapters/evm/contracts/mocks/TensorHarness.sol`

## Security Considerations

- Capsules are commitments only and MUST NOT be executable.
- Computation MUST be deterministic; nondeterminism MUST NOT influence capsules.
- External ownership checks may be adversarial and may revert.
- Implementations MUST treat reverts from external ownership checks as
  authorization failures.
- Verification acceptance events MUST be emitted only after successful checks.
- Implementations SHOULD bound iteration or rely on L2 environments.
- Improper upgrades can corrupt storage; storage libraries must be treated as
  immutable once published.

## Appendix A: Non-Normative Benchmarks

This appendix is informational only and MUST NOT be treated as a requirement.

### A.1 Benchmark Environment

- Backends: dense slot, bytecode payload, packed uint8
- Harness: TensorHarness (manager/read/write/batch/math facets)
- Runtime: Hardhat local network with viem estimateContractGas
- Batch chunk size: 256 elements
- Output: `scripts/benchmarks/output/tensorMathGas.md`

### A.2 Observations

- Dense slot writes are SSTORE bound and scale linearly.
- Payload writes reduce costs but still exceed L1 limits at 32x32 int256.
- Packed uint8 reduces slot count by ~32x for byte-sized tensors.
- Sparse updates and read-heavy workloads are viable on L1.
