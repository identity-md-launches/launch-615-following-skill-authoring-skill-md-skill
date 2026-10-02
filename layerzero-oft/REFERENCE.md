# LayerZero OFT route reference

This is implementation guidance, not a current registry of chains or deployment addresses. Verify interfaces and endpoint IDs against the project's pinned LayerZero packages and supplied deployment facts; never fetch live guidance as a substitute for those inputs.

## Route inventory and configuration

Treat a route as directional: `{ sourceEid, dstEid }`. The sending OFT at `sourceEid` stores the remote peer for `dstEid`; configuring A→B does not configure B→A. Store addresses as normalized 20-byte hex strings and endpoint IDs as integers. A reviewable route record should include:

```json
{
  "sourceChain": "ChainA",
  "sourceEid": 40101,
  "sourceOft": "0x1111111111111111111111111111111111111111",
  "destinationChain": "ChainB",
  "dstEid": 40202,
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

1. Read the sending OFT's peer for `dstEid` using `peers(uint32)` on OAppCore; there is no `getPeer` getter. Compare it to the expected encoded peer. Zero/unset is `NoPeer`; mismatch is `PeerMismatch`.
2. Read `enforcedOptions(uint32 eid, uint16 msgType)` on the OFT and compare options for the relevant message type/options type. Configure with `setEnforcedOptions(EnforcedOptionParam{eid,msgType,options}[])`. Record absent or mismatched options as a separate failing status.
3. Run `quoteSend(SendParam{dstEid,to,amountLD,minAmountLD,extraOptions,composeMsg,oftCmd}, bool payInLzToken)` returning `MessagingFee{nativeFee,lzTokenFee}` for the route using the intended recipient, amount, command, options, and fee-token mode. Preserve all inputs and both fee outputs. Quote errors are route failures, not zero-cost success.
4. Report readiness only when peer, enforced options, and quote all pass. A UI label alone is not evidence of on-chain setup.

LayerZero v2 OAppCore stores `mapping(uint32 eid => bytes32) public peers` on the OFT, set with `setPeer(uint32,bytes32)`. An unset peer reverts during quoting with the custom error `NoPeer(uint32 eid)` from IOAppCore, not an Error(string). Use v2-shaped EIDs (30xxx mainnet or 40xxx testnet), distinct from chain IDs. Inspect the pinned interfaces before writing code; make address-to-bytes32 conversion and decoding explicit and test it. Do not assume all peers are EVM addresses if the integration supports non-EVM peers.

## Foundry mock design

Mock only the endpoint; the OFT under test must use real OFT/OApp code. Peer and enforced-option state live on that OFT, never on the endpoint mock. Endpoint `quote(MessagingParams,address)` is view: validate the expected packet and sender inside the mock instead of writing captured parameters. Derive fees in the endpoint and compare the OFT return with its result; vary endpoint pricing to catch a constant fee implementation. Assertions should prove:

- each expected source/destination EID resolves to the expected peer;
- options keyed by both EID and message type reach the endpoint, including combined extra options and SEND versus SEND_AND_CALL selection;
- every configured direction reaches `quoteSend` with the expected destination EID and send parameters;
- a UI route with no source-side peer reverts with exactly `abi.encodeWithSelector(IOAppCore.NoPeer.selector, eid)` and is not send-ready;
- reverse routes are checked independently.

Test names and fixtures should name the route/EID. Do not claim a mock proves live endpoint behavior; it proves the integration's handling of the interface and failure states.

## Worked example

See `example/` for an offline Foundry test using vendored upstream OFT, OFTCore, IOFT, OAppCore, IOAppCore and OAppOptionsType3. The concrete OFT adds only its constructor. Required Solidity dependencies and provenance are in `example/vendor/`; no downloads or remappings are needed at test time. The endpoint mock checks destination, peer, encoded recipient/shared-decimal amount, composition payload, combined options, sender and payment mode. It does not simulate delivery.

Real projects use LayerZero devtools `TestHelperOz5` with `setUpEndpoints` and `wireOApps` for multi-endpoint delivery tests against their pinned packages. This example only proves the quote/configuration boundary; it does not validate live pricing, executor gas or delivery. See `example/docs/README.md` for the exact offline command and fixture limitations.
