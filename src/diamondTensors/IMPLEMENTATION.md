# NOTE: This is a tensor memory substrate, not an ML framework. The goal is to provide persistent, provenance-aware tensor storage and algebraic operations, not to replicate PyTorch or TensorFlow APIs or features.
# 📜 EIP-XXXX: Modular Tensor Memory & Capsules for EVM (Diamond-Native)

## Abstract

Defines a standard for **on-chain tensor memory**, **deterministic computation**, and **verifiable memory capsules**, implemented via ERC-2535 Diamonds. Enables agent memory, identity-bound state, verifiable computation graphs, and cross-chain state teleportation without trusted bridges.

---

## Motivation

Current smart contracts lack:

* Persistent structured memory
* Deterministic computation graphs
* Portable state verification
* Identity-aware memory binding

This EIP introduces **tensor-based memory primitives** and **capsule commitments** to solve these limitations.

This specification treats tokens as containers rather than receipts. The token is bound to tensor state and deterministic computation, not a pointer to off-chain bytes.

Tensors are structured arrays, not opaque blobs. Structure enables indexing and algebraic transforms that are deterministic on-chain.

---

## Appendix A: Non-Normative Benchmarks

This appendix is informational only. It illustrates observed gas behavior for reference backends in the repository and MUST NOT be treated as a performance requirement.

### A.1 Benchmark Environment

* Backends: DenseSlotTensor (`mapping(bytes32 => mapping(uint256 => int256))`), bytecode payload (SSTORE2-style), packed uint8 (32 elements per slot)
* Harness: `TensorHarness` (manager/read/write/batch/math facets)
* Runtime: Hardhat local network with viem `estimateContractGas`
* Batch chunk size: 256 elements
* Cost assumptions for USD estimates: 20 gwei gas price, $3000/ETH
* Output snapshots: `scripts/benchmarks/output/tensorMathGas.md`, `scripts/benchmarks/output/tensorMathGas.csv`

### A.2 Dense Tensor Operations

Dense writes are expensive on L1-class gas limits. Representative results observed under the reference backend:

* `batchSet`: ~23k-31k gas/element for sizes 2x2 through 32x32 (chunked)
* `batchGet`: ~3k-9k gas/element
* `add`/`scale`: succeed up to 16x16; 32x32 exceeded the block gas limit because reads and writes are both O(N)
* Payload writes (bytecode) reduce costs for dense tensors but still exceeded L1 limits at 32x32 int256 payloads
* Packed uint8 writes/read are substantially cheaper for byte-sized tensors and remain within L1 limits at 32x32

### A.3 Sparse Tensor Operations

Sparse updates are practical with the same backend and harness:

* 32x32 tensors at 1-10% density complete within block limits
* Per-element write costs remain ~23k-26k gas/element, but total gas scales with sparsity
* Reads remain materially cheaper than writes

### A.4 Observed Scaling Characteristics

* Dense writes are dominated by SSTORE costs and scale linearly with element count
* Dense math ops scale as read + write (approximately 2N storage ops)
* Backend choice dominates performance; identical tensor semantics can have radically different costs across storage models
* Payload writes scale with total byte length; packed uint8 reduces slot count by ~32x for byte-sized tensors

### A.5 Implications for Implementers

* These results are illustrative, not prescriptive
* Dense tensors on L1 are generally infeasible without specialized backends
* Sparse updates and read-heavy workflows are viable on standard storage
* Packed backends are dtype-specific and require explicit metadata flags to preserve semantics
* Example: a 1 MB packed uint8 payload is ~800M gas to write in this harness, well above L1 block limits
* L2/validium/app-chain deployments and alternative backends (bytecode storage, packed formats, external DA) are expected to materially change gas behavior

## Specification

### Core Concepts

#### Tensor

* Multi-dimensional structured memory
* Deterministic identifier via `(owner, seed, nonce)`
* Flat storage with shape metadata

#### Facet Architecture

* `TensorManagerFacet` — lifecycle
* `TensorReadFacet` / `TensorWriteFacet` — IO
* `TensorBatchFacet` — vectorized operations
* `TensorMathFacet` — deterministic computation
* `CapsuleFacet` — deterministic freezing
* `CapsuleRegistryFacet` — append-only provenance
* `NFTBindingFacet` — identity binding

#### Capsule

* Cryptographic commitment to tensor state
* Immutable, replayable, chain-agnostic
* Represented by a `bytes32 capsuleRoot`

#### Deployment Considerations

This specification targets high-throughput or low-cost EVM environments (L2s, validiums, app-chains). Mainnet use is limited to small tensors or anchoring and verification.

---

## Storage

This specification defines a modular, upgradeable storage architecture for tensor-based memory and capsule provenance using the ERC-2535 Diamond Standard.

### Storage Model

All state defined by this specification is stored in a single, deterministic storage namespace accessed via a Diamond storage pattern. A canonical storage slot is defined as:

```
keccak256("diamond.tensor.core.storage.v1")
```

All facets defined by this specification MUST read from and write to this storage layout. No facet may introduce independent or overlapping storage for tensor state, capsule state, or lineage.

### Canonical Layout

The canonical storage layout consists of the following components:

#### Tensor Metadata

* Tensor identifier (`bytes32`)
* Owner address
* Rank and shape
* Precomputed total size
* Creation timestamp
* Reserved fields for forward compatibility

#### Tensor Data

* Flat, index-addressable storage mapping
* Deterministic flattening of multi-dimensional indices
* Signed integer value domain (`int256`)

#### Ownership Indexing

* Owner address to tensor identifiers mapping
* Deterministic enumeration of owned tensors

#### NFT Binding

* NFT contract address and tokenId bound to tensorId
* Immutable binding flag and bind timestamp

#### Deterministic Nonces

* Owner- and seed-scoped nonce tracking
* Enables reproducible tensor identifiers across chains

#### Capsule Provenance

* Latest capsule root per tensor
* Append-only capsule registry per tensor
* Each registry entry contains:

  * Capsule root hash
  * Timestamp
  * Owner at time of registration

### Capsule Storage Semantics

Capsule data represents cryptographic commitments to frozen tensor state. Capsule storage is **append-only** and immutable once written. No mechanism exists to delete, reorder, or overwrite capsule records.

Capsule lineage is intentionally stored alongside tensor state in the same storage namespace. This couples memory and provenance at the storage level, ensuring that tensor state and its historical truth anchors cannot diverge.

Future versions MAY extract capsule storage into a separate namespace; however, implementations compliant with this specification MUST preserve the unified layout for version `v1`.

### Tensor Metadata Flags

The `flags` field is a 32-bit bitfield intended for compact, deterministic hints:

* bits 0-7: base dtype (int8, int16, int32, float16, etc.)
* bits 8-15: semantic hint (image, audio, mesh, weights)
* bits 16-23: encoding (raw, RLE, LZ, custom)
* bits 24-31: reserved

Implementations MAY provide registries that map flags to MIME types or codecs. Strings SHOULD be avoided in storage.

### Encodings and Lazy Validation

Implementations that accept encoded or compressed tensor payloads MUST NOT parse or validate payloads during writes. Reads MAY revert if payloads are invalid or inconsistent with metadata.

### Upgradeability

This specification relies on the following invariants to ensure safe upgradeability:

1. Storage layout MUST be append-only.
2. No field in the canonical layout may be reordered or removed.
3. New fields MAY be appended to the layout.
4. All logic changes MUST be introduced via new facets.
5. Existing facets MUST NOT reinterpret existing storage fields.

Violating these invariants results in undefined behavior and renders the implementation non-compliant.

---

## Optional Extensions (Non-Normative)

The core specification defines tensor semantics and indexing, not storage backends. Implementations MAY provide backend facets for alternative payload storage or retrieval, such as:

* In-slot tensor storage (small tensors)
* Bytecode-backed storage (e.g., SSTORE2)
* Calldata-backed storage (ephemeral)
* External DA-backed storage (validium DA)

These backends are deployment choices and MUST NOT change tensor semantics.

---

## Security Considerations

This specification is designed to prioritize determinism, auditability, and safety over expressiveness.

### No Executable Payloads

Capsules defined by this specification are **cryptographic commitments only**. They do not contain executable code, instructions, or evaluable expressions. Implementations MUST NOT execute, deserialize, or interpret capsule data as code.

### Deterministic Computation

All tensor operations defined by this specification are deterministic and replayable. Given identical inputs, seeds, and ordering, compliant implementations MUST produce identical outputs.

Non-deterministic sources such as timestamps, block hashes, randomness, or external calls MUST NOT influence tensor computation or capsule formation.

### Ownership Enforcement

All tensor mutation, computation, and capsule registration operations are restricted to the tensor owner. Ownership checks MUST be enforced at the facet level prior to any state mutation or capsule registration.

NFT-bound tensors derive authority from the owning NFT’s `ownerOf` resolution at the time of invocation.

Implementations MUST treat external ownership checks as potentially adversarial: a malicious ERC-721 may revert or return bad data, but MUST NOT grant unauthorized control.

### Verification Event Discipline

When external verification is used (e.g., capsule submission), acceptance events MUST be emitted only after successful verification. Failed verification MUST NOT emit stateful events.

### Immutable Provenance

Capsule records are append-only. Once a capsule root is registered, it cannot be altered or removed. This provides immutable provenance suitable for auditing, cross-chain verification, and replay.

### Bounded Execution

Facet implementations SHOULD avoid unbounded loops over storage. Where iteration over tensor data is required, implementations SHOULD enforce practical size limits or rely on Layer-2 execution environments with appropriate gas guarantees.

### No Implicit Trust in Off-Chain Systems

This specification does not assume trust in off-chain indexers, bridges, or execution environments. Capsule roots MAY be verified off-chain or on other chains, but on-chain correctness depends solely on storage integrity and deterministic computation.

### Upgrade Safety

Because this specification is designed for Diamond-based systems, improper upgrades pose the primary security risk. Implementers SHOULD:

* Freeze storage layout definitions per version
* Audit all new facets prior to deployment
* Avoid reusing storage slots for new semantics
* Treat storage libraries as immutable once published

---

## Use Cases

* Agent cognition and memory
* NFT-bound identity state
* Verifiable AI inference steps
* Cross-chain state teleportation
* Provenance and audit systems

---

## Reference Implementation

* **DiamondTensorCore**
* Solidity ≥ 0.8.24
* ERC-2535 compliant
* L2-ready (Skale, Arbitrum, Base)

---
