
https://github.com/Perfect-Abstractions/Compose/discussions/238

A new design goal of Compose is to future proof it against major changes to the Solidity language which are coming.

    The Solidity team has announced they are removing inheritance entirely from the language.

From the Solidity blog:

    In addition to growing and expanding the language, we will also be removing or reworking some existing features. We are already certain that we will be removing inheritance entirely. Additional changes are less certain, but we are considering potentially replacing or reworking features like try/catch, libraries, function pointers, type conversion, and data locations.

Compose is already designed so it doesn't use inheritance.

The Solidity team is also planning to remove or replace Solidity libraries.

From a comment from a Solidity Compiler Team member:

    We’ve long been dissatisfied with libraries and planning to drop them in the transition.

For future proofing Compose and making it simpler, I am thinking about removing Solidity libraries from Compose and instead using "Compose Libraries", which are simply Solidity files which declare constants, structs and free functions. I have done some testing on this and it works fine. I am interested in feedback on this change.
Start with Step 1: Audit Existing Libraries

Search for all library declarations in src and lib.
List each library and its file path in your TODO or a new tracking document.
Move sequentially through the plan

For each library, complete Step 2 (usage documentation), then Step 3 (design replacement), and so on.
After each step, update your TODO with findings, progress, and blockers.
Assign tasks if working with a team

Divide libraries among contributors for parallel migration.
Create a migration branch

Work on a dedicated branch (e.g., remove-solidity-libraries) for all changes.
Track progress

Use checkboxes or status tags in your TODO for each step and library.
Communicate

Post regular updates in your PR and project discussion channels.
After migration, review and merge

Run all tests, document the change, and request review before merging.
If you want, I can help you start the audit or generate a checklist for the libraries fo
1. Audit Existing Libraries

List all Solidity libraries currently used in Compose (search for library keyword in src and lib).
2. Identify Library Usage

For each library, document where and how it is used (functions, structs, constants).
3. Design Compose Library Replacements

For each Solidity library, create a new .sol file (e.g., LibUtils.sol → Utils.sol) that:
Declares only structs, constants, and free (standalone) functions.
Removes the library keyword and any using for statements.
4. Refactor Imports and Usages

Update all contracts and facets to import the new Compose Library files.
Replace any using LibX for Y; with direct calls to free functions.
5. Remove Solidity Library Artifacts

Delete the original Solidity library files after migration.
Remove any references to libraries in documentation and comments.
6. Test Thoroughly

Run all tests to ensure no breakage.
Validate that all migrated functions behave identically.
7. Document the Change

Update README and developer docs to explain the new Compose Library pattern.
Note the rationale: future-proofing for Solidity changes.
8. PR and Review

Submit the migration as a single PR.

## Compose Library Migration Plan (future-proofing Solidity libraries)

### Step 1 — Audit (complete)
- Searched with `rg "^\s*library\s+" src lib` to inventory Solidity libraries.
- Inventory — internal (src) (Step 1 complete; Steps 2–5 pending):
  - [ ] LibERC165 — src/interfaceDetection/ERC165/LibERC165.sol
  - [ ] LibAccessControl — src/access/AccessControl/LibAccessControl.sol
  - [ ] LibOwnerTwoSteps — src/access/OwnerTwoSteps/LibOwnerTwoSteps.sol
  - [ ] LibShardedLoupe — src/diamond/LibShardedLoupe.sol
  - [ ] LibAccessControlTemporal — src/access/AccessControlTemporal/LibAccessControlTemporal.sol
  - [ ] LibUtils — src/libraries/LibUtils.sol
  - [ ] LibNonReentrancy — src/libraries/LibNonReentrancy.sol
  - [ ] LibBlob — src/libraries/LibBlob.sol
  - [ ] LibAccessControlPausable — src/access/AccessControlPausable/LibAccessControlPausable.sol
  - [ ] LibERC1155 — src/token/ERC1155/LibERC1155.sol
  - [ ] LibERC721 — src/token/ERC721/ERC721Enumerable/LibERC721Enumerable.sol (library name matches LibERC721)
  - [ ] LibDiamond — src/diamond/LibDiamond.sol
  - [ ] LibRoyalty — src/token/Royalty/LibRoyalty.sol
  - [ ] LibOwner — src/access/Owner/LibOwner.sol
  - [ ] LibDiamondQuery — src/diamond/LibDiamondQuery.sol
  - [ ] LibDiamondShard — src/diamond/LibDiamondShard.sol
  - [ ] LibERC20 — src/token/ERC20/ERC20/LibERC20.sol
  - [ ] LibERC721 — src/token/ERC721/ERC721/LibERC721.sol (second LibERC721 definition; watch for naming collision during migration)
- Inventory — vendored (lib/forge-std) (likely out of scope for Compose migration, but noted):
  - [ ] console — lib/forge-std/src/console.sol
  - [ ] LibVariable — lib/forge-std/src/LibVariable.sol
  - [ ] safeconsole — lib/forge-std/src/safeconsole.sol
  - [ ] stdJson — lib/forge-std/src/StdJson.sol
  - [ ] stdError — lib/forge-std/src/StdError.sol
  - [ ] stdToml — lib/forge-std/src/StdToml.sol
  - [ ] stdStorageSafe — lib/forge-std/src/StdStorage.sol
  - [ ] stdStorage — lib/forge-std/src/StdStorage.sol
  - [ ] StdConstants — lib/forge-std/src/StdConstants.sol
  - [ ] StdStyle — lib/forge-std/src/StdStyle.sol
  - [ ] stdMath — lib/forge-std/src/StdMath.sol

### Next steps (to execute sequentially)
- Step 2 — Usage documentation: map functions/structs/constants and call sites for each internal library.
- Step 3 — Compose library design: propose replacement filenames (e.g., LibX.sol → X.sol) and free-function signatures.
- Step 4 — Refactor imports/usings: swap `using` statements for direct calls and point imports to the new Compose library files.
- Step 5 — Remove Solidity library artifacts: delete legacy library files and clean up comments/references.
- Step 6 — Test and validate: run full test suite and targeted checks for migrated pieces.
- Step 7 — Document/PR: describe the new pattern, rationale, and migration notes; open PR for review.
