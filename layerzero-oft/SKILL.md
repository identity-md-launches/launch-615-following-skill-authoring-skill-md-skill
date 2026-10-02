---
id: layerzero-oft
version: 1
description: Configure and document LayerZero OFT routes, verify peers and enforced options, quote each route, and test failures with mocked endpoints.
role: implement
kind: code
judge: verifier-paths
checks: none
requires:
variables:
  - objective
reads:
  - skill:layerzero-oft
# Frontmatter choices: this is implementation work, but the verifier has no OFT suite, so checks none and verifier-paths are honest. The caller supplies repository-specific paths; objective carries chain, token and route facts.
objective: "{{objective}}"
acceptanceCriteria:
  - The delivered route configuration records source and destination endpoint IDs, peer addresses, enforced options, and the intended send mode for every requested route
  - The delivered route health checklist checks on-chain peer configuration per endpoint ID, enforced options, and quoteSend for every displayed route, and identifies an unset peer as NoPeer
  - The delivered Foundry tests use mocked endpoints and cover configured and unconfigured peers, enforced options, and quoteSend on each configured route
  - The delivered documentation explains deployment and verification steps and clearly labels the integration experimental
mustProduce:
  - layerzero-oft/config/routes.json
  - layerzero-oft/test/LayerZeroOFT.t.sol
  - layerzero-oft/docs/README.md
---

Experimental, commissioned as a test of the IMD swarm. It may not work as described. Read the code, start with small amounts, no warranty.

You are integrating an OFT into the repository named by the objective. Treat route data supplied there as authoritative; do not invent endpoint IDs, peers, token addresses, or send requirements. Ask no questions: document missing facts as blockers and do not present an incomplete route as ready.

1. Inspect the existing OFT implementation, deployment/configuration conventions, route list, and Foundry setup. Keep changes within the caller's path budget. Open the pinned `REFERENCE.md` before choosing the configuration, health-check, or mock design.
2. Produce `layerzero-oft/config/routes.json`, `layerzero-oft/test/LayerZeroOFT.t.sol`, and `layerzero-oft/docs/README.md`, adapting the requested project's agreed interfaces. If these paths cannot fit its conventions or the write budget, report the conflict instead of silently changing the budget.
3. Run the project's Foundry tests if available and report the exact command and result. Never claim tests passed when dependencies or configuration prevent execution.

**Model routes as directed pairs.** A route from endpoint A to endpoint B needs the configured remote peer for B on the source OFT at A; its reverse is a separate route and needs its own source-side peer. Record endpoint IDs explicitly, not just chain names. Never assume a UI route means the peer is set on chain.

**Check the bytes sent.** Read `enforcedOptions(uint32 eid, uint16 msgType)` on the OFT and configure it with `setEnforcedOptions(EnforcedOptionParam[])`. Record enforced options for the actual message type and options type expected by the deployed OFT. Keep required receive gas and any other agreed options explicit. Do not guess gas amounts or copy options from another route without documenting why they apply.

**Quote every direction.** Call `quoteSend(SendParam{dstEid,to,amountLD,minAmountLD,extraOptions,composeMsg,oftCmd}, bool payInLzToken)` returning `MessagingFee{nativeFee,lzTokenFee}` using each route's actual destination endpoint ID, recipient, amount, command, options and pay-in-LZ-token choice. Record the quote inputs, returned native/LZ-token fees, chain and block. A quote is a point-in-time check, not a guarantee that a later send will succeed.

**Make UI-only routes fail visibly.** For every route displayed to a user, compare the UI route inventory with on-chain peer state. If the source OFT's `peers(dstEid)` is zero or otherwise unset, mark the route `NoPeer`, suppress send readiness, and include the missing source OFT and destination endpoint ID in the report. Also check enforced options and the route's quote; do not collapse these distinct failures into one green status.

**Use mocked endpoints in Foundry tests.** Exercise real OFT code with only the endpoint mocked. Peers belong to the OFT (`setPeer(uint32,bytes32)` and `peers(uint32)`); OAppCore has no `getPeer` getter. Cover each configured route's peer, enforced options and quote path, plus an unset peer reverting with `abi.encodeWithSelector(IOAppCore.NoPeer.selector, eid)` for the custom error `NoPeer(uint32)`. Verify that fees come from endpoint `quote` and that the expected message and combined options reach it. Avoid tests that only assert mock setup or hard-code a passing result.

**Finish with actionable evidence.** Documentation must tell an operator how to configure peers, set options, run per-route quotes and health checks, and interpret NoPeer. List unresolved chain facts and failed commands in the final message. Do not imply a route is production-ready on the basis of this skill's example.
