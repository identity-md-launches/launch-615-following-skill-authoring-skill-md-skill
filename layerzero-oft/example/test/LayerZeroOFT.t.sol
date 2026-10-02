// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OFT} from "../vendor/@layerzerolabs/oft-evm/contracts/OFT.sol";
import {IOFT, SendParam, MessagingFee} from "../vendor/@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOAppCore} from "../vendor/@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {EnforcedOptionParam} from "../vendor/@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {
    MessagingParams
} from "../vendor/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Ownable} from "../vendor/@openzeppelin/contracts/access/Ownable.sol";

// Constructor only: all peer, options, token and quote behavior is upstream production code.
contract ExampleOFT is OFT {
    constructor(address endpoint) OFT("Example", "OFT", endpoint, msg.sender) Ownable(msg.sender) {}
}

// Only the endpoint boundary is mocked. quote is view, so validate inputs instead of recording writes.
contract MockEndpoint {
    bytes32 private expectedQuote;
    uint256 private tariff = 11;
    bool private failQuote;
    error QuoteUnavailable();

    function setDelegate(address) external {}

    function expectQuote(MessagingParams memory params, address sender) external {
        expectedQuote = keccak256(abi.encode(params, sender));
    }

    function setTariff(uint256 value) external {
        tariff = value;
    }

    function setFailQuote(bool value) external {
        failQuote = value;
    }

    // Deliberately synthetic pricing, dependent on the full packet and a mutable endpoint tariff.
    function feeFor(MessagingParams memory params) public view returns (MessagingFee memory) {
        uint256 units = uint256(keccak256(abi.encode(params))) % 1e12 + 1;
        return MessagingFee(units * tariff, params.payInLzToken ? units * (tariff + 1) : 0);
    }

    function quote(MessagingParams calldata params, address sender) external view returns (MessagingFee memory) {
        require(msg.sender == sender, "quote caller is not OFT");
        require(keccak256(abi.encode(params, sender)) == expectedQuote, "wrong endpoint quote inputs");
        if (failQuote) revert QuoteUnavailable();
        return feeFor(params);
    }
}

contract LayerZeroOFTRouteTest {
    uint32 private constant EID_A = 40101;
    uint32 private constant EID_B = 40202;
    uint32 private constant EID_C = 40303;
    MockEndpoint private endpoint;
    ExampleOFT private source;
    bytes32 private constant PEER_B = bytes32(uint256(uint160(0x2222222222222222222222222222222222222222)));
    bytes32 private constant RECIPIENT_B = bytes32(uint256(uint160(0x3333333333333333333333333333333333333333)));
    bytes private options = hex"00030100110100000000000000000000000000030d40";
    bytes private composeOptions = hex"00030100110100000000000000000000000000061a80";

    function setUp() public {
        endpoint = new MockEndpoint();
        source = new ExampleOFT(address(endpoint));
        source.setPeer(EID_B, PEER_B);
        EnforcedOptionParam[] memory enforced = new EnforcedOptionParam[](2);
        enforced[0] = EnforcedOptionParam({eid: EID_B, msgType: source.SEND(), options: options});
        enforced[1] = EnforcedOptionParam({eid: EID_B, msgType: source.SEND_AND_CALL(), options: composeOptions});
        source.setEnforcedOptions(enforced);
    }

    function _sendParam(uint32 eid, uint256 amount) private pure returns (SendParam memory) {
        return SendParam({
            dstEid: eid,
            to: RECIPIENT_B,
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: hex""
        });
    }

    // Expected wire bytes are constructed independently of the production codec and combineOptions.
    function _packet(SendParam memory param, bytes32 peer, bytes memory expectedOptions, bool payInLzToken)
        private
        view
        returns (MessagingParams memory)
    {
        bytes memory message = abi.encodePacked(param.to, uint64(param.amountLD / 1e12));
        if (param.composeMsg.length != 0) {
            message =
                bytes.concat(message, abi.encodePacked(bytes32(uint256(uint160(address(this)))), param.composeMsg));
        }
        return MessagingParams(param.dstEid, peer, message, expectedOptions, payInLzToken);
    }

    function _assertQuote(ExampleOFT oft, MockEndpoint ep, SendParam memory param, MessagingParams memory packet)
        private
        returns (MessagingFee memory actual)
    {
        ep.expectQuote(packet, address(oft));
        MessagingFee memory expected = ep.feeFor(packet);
        actual = oft.quoteSend(param, packet.payInLzToken);
        require(actual.nativeFee == expected.nativeFee, "endpoint native fee not forwarded");
        require(actual.lzTokenFee == expected.lzTokenFee, "endpoint token fee not forwarded");
    }

    function testConfiguredRoute40202UsesPeerOptionsAndEndpointFee() public {
        SendParam memory param = _sendParam(EID_B, 1 ether);
        require(source.peers(EID_B) == PEER_B, "peer mismatch");
        require(keccak256(source.enforcedOptions(EID_B, source.SEND())) == keccak256(options), "options mismatch");
        MessagingParams memory packet = _packet(param, PEER_B, options, false);
        MessagingFee memory beforeFee = _assertQuote(source, endpoint, param, packet);
        endpoint.setTariff(29);
        MessagingFee memory afterFee = _assertQuote(source, endpoint, param, packet);
        require(afterFee.nativeFee != beforeFee.nativeFee, "quote ignores endpoint pricing");
    }

    function testFuzzQuote40202EncodesRecipientAmountAndPayment(uint64 amountSD, bytes32 recipient, bool payInLzToken)
        public
    {
        SendParam memory param = _sendParam(EID_B, uint256(amountSD) * 1e12);
        param.to = recipient;
        // Dust must be removed by real OFT code before the endpoint sees the packet.
        param.amountLD += 123;
        _assertQuote(source, endpoint, param, _packet(param, PEER_B, options, payInLzToken));
    }

    function testCompose40202SelectsMessageTypeAndCombinesExtraOptions() public {
        SendParam memory param = _sendParam(EID_B, 2 ether);
        param.composeMsg = hex"aabbcc";
        param.extraOptions = options;
        bytes memory combined = bytes.concat(composeOptions, hex"0100110100000000000000000000000000030d40");
        _assertQuote(source, endpoint, param, _packet(param, PEER_B, combined, true));
        param.composeMsg = hex"";
        combined = bytes.concat(options, hex"0100110100000000000000000000000000030d40");
        _assertQuote(source, endpoint, param, _packet(param, PEER_B, combined, false));
    }

    function _assertNoPeer(ExampleOFT oft, uint32 eid) private view {
        (bool ok, bytes memory reason) =
            address(oft).staticcall(abi.encodeCall(IOFT.quoteSend, (_sendParam(eid, 1 ether), false)));
        require(!ok, "unconfigured UI route reported ready");
        require(
            keccak256(reason) == keccak256(abi.encodeWithSelector(IOAppCore.NoPeer.selector, eid)), "not NoPeer(eid)"
        );
    }

    function testUiVisibleRoute40303WithoutPeerIsNoPeer() public view {
        _assertNoPeer(source, EID_C);
    }

    function testRemovedPeer40202IsNoPeer() public {
        source.setPeer(EID_B, bytes32(0));
        _assertNoPeer(source, EID_B);
    }

    function testReverseRoute40101IsIndependentlyConfiguredAndQuoted() public {
        MockEndpoint reverseEndpoint = new MockEndpoint();
        ExampleOFT reverseSource = new ExampleOFT(address(reverseEndpoint));
        _assertNoPeer(reverseSource, EID_A);
        bytes32 peerA = bytes32(uint256(uint160(address(source))));
        reverseSource.setPeer(EID_A, peerA);
        EnforcedOptionParam[] memory enforced = new EnforcedOptionParam[](1);
        enforced[0] = EnforcedOptionParam({eid: EID_A, msgType: reverseSource.SEND(), options: composeOptions});
        reverseSource.setEnforcedOptions(enforced);
        SendParam memory param = _sendParam(EID_A, 2 ether);
        _assertQuote(reverseSource, reverseEndpoint, param, _packet(param, peerA, composeOptions, false));
        // A second destination on the same OFT must not inherit EID_B's enforced options.
        source.setPeer(EID_C, peerA);
        param.dstEid = EID_C;
        _assertQuote(source, endpoint, param, _packet(param, peerA, hex"", false));
    }

    function testQuote40202PropagatesEndpointFailure() public {
        SendParam memory param = _sendParam(EID_B, 1 ether);
        endpoint.expectQuote(_packet(param, PEER_B, options, false), address(source));
        endpoint.setFailQuote(true);
        (bool ok, bytes memory reason) = address(source).staticcall(abi.encodeCall(IOFT.quoteSend, (param, false)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSelector(MockEndpoint.QuoteUnavailable.selector)),
            "quote failure hidden"
        );
    }

    function testQuote40202RejectsSlippageBeforeEndpoint() public view {
        SendParam memory param = _sendParam(EID_B, 1 ether + 1);
        (bool ok, bytes memory reason) = address(source).staticcall(abi.encodeCall(IOFT.quoteSend, (param, false)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(IOFT.SlippageExceeded.selector, 1 ether, 1 ether + 1)),
            "slippage not checked"
        );
    }
}
