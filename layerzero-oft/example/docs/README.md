# Example OFT route checks

Experimental, commissioned as a test of the IMD swarm. It may not work as described. Read the code, start with small amounts, no warranty.

This dependency-free example represents two UI-visible directions between ExampleA (EID 101) and ExampleB (EID 202). `config/routes.json` records a peer and explicit options per direction. The sample IDs, peer addresses and gas option are illustrative only.

The test mock models the integration boundary: the source-side peer mapping, enforced options, and a quote that captures `dstEid`, recipient and amount. The test checks a configured route, quote inputs, the reverse direction as independent state, and a UI-listed route without a peer reverting with `NoPeer`.

In a project, adapt the mock and test to its pinned OFT/endpoint interfaces. For every UI-visible route, read the source OFT peer for that route's destination EID, compare enforced options, then call `quoteSend` with the intended send parameters and record the fee response with chain/block context. A missing peer is `NoPeer` and the UI must not show the route as send-ready. Run the project's Foundry suite after adapting the example.
