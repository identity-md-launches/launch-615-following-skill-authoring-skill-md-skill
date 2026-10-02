// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Dependency-free mock boundary illustrating assertions a real OFT integration test should make.
contract MockEndpoint {
    mapping(uint32 => bytes32) public peers;
    mapping(uint32 => bytes) public enforcedOptions;
    uint32 public quotedDstEid;
    bytes32 public quotedRecipient;
    uint256 public quotedAmount;

    function setPeer(uint32 dstEid, bytes32 peer) external { peers[dstEid] = peer; }
    function setEnforcedOptions(uint32 dstEid, bytes calldata options) external { enforcedOptions[dstEid] = options; }

    function quoteSend(uint32 dstEid, bytes32 recipient, uint256 amount) external returns (uint256 nativeFee) {
        require(peers[dstEid] != bytes32(0), "NoPeer");
        quotedDstEid = dstEid;
        quotedRecipient = recipient;
        quotedAmount = amount;
        return 7;
    }
}

contract LayerZeroOFTRouteTest {
    MockEndpoint private source;
    bytes32 private constant PEER_B = bytes32(uint256(uint160(0x2222222222222222222222222222222222222222)));
    bytes32 private constant RECIPIENT_B = bytes32(uint256(uint160(0x3333333333333333333333333333333333333333)));
    bytes private options = hex"00030100110100000000000000000000000000030d40";

    function setUp() public {
        source = new MockEndpoint();
        source.setPeer(202, PEER_B); // ExampleA -> ExampleB; reverse is a separate source configuration.
        source.setEnforcedOptions(202, options);
    }

    function testConfiguredRoutePeerAndOptions() public view {
        require(source.peers(202) == PEER_B, "peer mismatch");
        require(keccak256(source.enforcedOptions(202)) == keccak256(options), "options mismatch");
    }

    function testQuoteUsesConfiguredDestinationAndInputs() public {
        uint256 fee = source.quoteSend(202, RECIPIENT_B, 1 ether);
        require(fee == 7, "unexpected mock fee");
        require(source.quotedDstEid() == 202, "wrong dstEid");
        require(source.quotedRecipient() == RECIPIENT_B, "wrong recipient");
        require(source.quotedAmount() == 1 ether, "wrong amount");
    }

    function testUiVisibleRouteWithoutPeerIsNoPeer() public {
        MockEndpoint unconfiguredSource = new MockEndpoint(); // UI still lists ExampleA -> ExampleC.
        (bool ok, bytes memory reason) = address(unconfiguredSource).call(
            abi.encodeCall(unconfiguredSource.quoteSend, (303, RECIPIENT_B, 1 ether))
        );
        require(!ok, "unconfigured UI route reported ready");
        require(keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "NoPeer")), "not NoPeer");
    }

    function testReverseRouteIsIndependentlyConfiguredAndQuoted() public {
        MockEndpoint reverseSource = new MockEndpoint();
        bytes32 peerA = bytes32(uint256(uint160(0x1111111111111111111111111111111111111111)));
        reverseSource.setPeer(101, peerA);
        reverseSource.setEnforcedOptions(101, options);
        require(reverseSource.peers(101) == peerA, "reverse peer mismatch");
        require(keccak256(reverseSource.enforcedOptions(101)) == keccak256(options), "reverse options mismatch");
        require(reverseSource.quoteSend(101, RECIPIENT_B, 2 ether) == 7, "reverse quote failed");
        require(reverseSource.quotedDstEid() == 101, "reverse quote used wrong dstEid");
        require(reverseSource.quotedAmount() == 2 ether, "reverse quote used wrong amount");
    }
}
