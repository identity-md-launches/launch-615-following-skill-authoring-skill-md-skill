# Example OFT route checks

Experimental, commissioned as a test of the IMD swarm. It may not work as described. Read the code, start with small amounts, no warranty.

The executable example uses illustrative v2-shaped EIDs 40101 (ExampleA), 40202 (ExampleB), and 40303 (an unconfigured UI route). These IDs, addresses and gas options are fixture values, not deployment facts. `config/routes.json` uses the same v2-shaped EIDs (40101, 40202) and is not consumed by the Foundry test; `check-routes.mjs` checks it independently.

The concrete OFT inherits vendored upstream OFT code, adding only its constructor. The endpoint alone is mocked. Tests exercise peer lookup, both enforced-option keys, SEND versus SEND_AND_CALL, extra-option combination, recipient and shared-decimal encoding, dust removal, both payment modes, fee forwarding under changing endpoint pricing, endpoint quote failure, slippage, independent reverse configuration, and exact `NoPeer(uint32)` revert data. The endpoint validates quote inputs in its view function instead of attempting storage writes during a static call. Fees are synthetic, never predictions of live pricing.

Run from the repository root with Foundry and solc 0.8.30 already installed:

```sh
FOUNDRY_SRC=layerzero-oft/example/vendor \
FOUNDRY_TEST=layerzero-oft/example/test \
FOUNDRY_OUT=test/scratch/out \
FOUNDRY_CACHE_PATH=test/scratch/cache \
forge test --offline --use 0.8.30 -vv
forge fmt --check layerzero-oft/example/test/LayerZeroOFT.t.sol
node layerzero-oft/example/check-routes.mjs
node check-skill.mjs layerzero-oft
```

All imported Solidity is included as ordinary files; versions, archive hashes and licenses are in `../vendor/README.md`. No configuration files, remappings or network access are needed. Local validation: eight tests passed, including 256 fuzz cases, with Foundry 1.8.3 and solc 0.8.30.

In a project, configure `setPeer(dstEid, peer)` on each source OFT and `setEnforcedOptions(EnforcedOptionParam[])` for each EID/message type. For every UI-visible direction, read `peers(dstEid)` and `enforcedOptions(dstEid,msgType)`, then call `quoteSend(SendParam,bool)` and record both returned fees with chain/block context. A zero peer means `NoPeer`; suppress send readiness. The standard OFT leaves `oftCmd` unused; this fixture uses empty command bytes. Real projects use `TestHelperOz5`, `setUpEndpoints` and `wireOApps` for delivery coverage. This fixture neither sends nor deploys on chain.
