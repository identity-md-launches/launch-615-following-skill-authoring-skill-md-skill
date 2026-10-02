# LayerZero OFT route reference

This is implementation guidance, not a current registry of chains or deployment addresses. Verify interfaces and endpoint IDs against the project's pinned LayerZero packages and supplied deployment facts; never fetch live guidance as a substitute for those inputs.

## Route inventory and configuration

Treat a route as directional: `{ sourceEid, dstEid }`. The sending OFT at `sourceEid` stores the remote peer for `dstEid`; configuring A→B does not configure B→A. Store addresses as normalized 20-byte hex strings and endpoint IDs as integers. A reviewable route record should include:

```json
{
  "sourceChain": "ChainA",
  "sourceEid": 101,
  "sourceOft": "0x1111111111111111111111111111111111111111",
  "destinationChain": "ChainB",
  "dstEid": 202,
  "peer": "0x2222222222222222222222222222222222222222",
  "messageType": 1,
  "optionsType": "lzReceive",
  "optionsHex": "0x00030100110100000000000000000000000000030d40",
  "sendMode": "native",
  "uiVisible": true
}
```

This value illustrates shape only; addresses, EIDs, message types, option bytes and gas limits are not defaults. Use the SDK/package version and project requirements to decode and produce options. Include every UI-visible route, including routes intentionally disabled, with an explicit reason/status so missing on-chain configuration cannot disappear from the inventory.

## Operational checks

For each UI-visible directional route, at a recorded block:

1. Read the sending OFT's peer for `dstEid` (commonly `peers(uint32)` or `getPeer(uint32)` depending on the deployed version). Compare it to the expected encoded peer. Zero/unset is `NoPeer`; mismatch is `PeerMismatch`.
2. Read and compare enforced options for the relevant message type/options type. Record absent or mismatched options as a separate failing status.
3. Run the deployment's `quoteSend` path for the route using the intended recipient, amount, command, options, and fee-token mode. Preserve all inputs and both fee outputs. Quote errors are route failures, not zero-cost success.
4. Report readiness only when peer, enforced options, and quote all pass. A UI label alone is not evidence of on-chain setup.

LayerZero OFT V2 commonly exposes endpoint IDs as `uint32`, peers as bytes32-encoded addresses, and quote functions taking a send parameter tuple plus an LZ-token payment flag. Actual signatures vary by package and wrapper. Inspect the pinned interfaces before writing code; make address-to-bytes32 conversion and decoding explicit and test it. Do not assume all peers are EVM addresses if the integration supports non-EVM peers.

## Foundry mock design

Mock the smallest endpoint/OFT boundary needed by the repository's actual interface. Prefer exercising the production route health/configuration adapter rather than recreating LayerZero behavior in a test-only copy. Mocks should expose observable peer and enforced-option state, capture quote parameters, and allow an unset peer or quote revert. Assertions should prove:

- each expected source/destination EID resolves to the expected peer;
- configured options are read/set for the expected message and options types;
- every configured direction reaches `quoteSend` with the expected destination EID and send parameters;
- an endpoint route present in the UI inventory with no source-side peer reports `NoPeer` and is not send-ready;
- reverse routes are checked independently.

Test names and fixtures should name the route/EID. Do not claim a mock proves live endpoint behavior; it proves the integration's handling of the interface and failure states.

## Worked example

See `example/` for a dependency-free harness demonstrating directional peer setup, options and a route quote. It is an executable-shaped illustration of the acceptance criteria, not a LayerZero deployment template. In a real project, adapt it to the pinned OFT and endpoint interfaces and avoid using the sample IDs or addresses.
