# Pinned Solidity dependencies

Only the transitive Solidity imports of OFT.sol are included. Upstream source is unchanged except import paths are made relative for offline compilation without remappings. SPDX notices are retained. OpenZeppelin's MIT license and LayerZero's MIT and LZBL-1.2 texts are included. The two protocol libraries AddressCast and PacketV1Codec carry LZBL-1.2; other included Solidity files carry MIT.

- `@layerzerolabs/oft-evm@4.0.1`: https://registry.npmjs.org/@layerzerolabs/oft-evm/-/oft-evm-4.0.1.tgz (SHA-256 `ee4269c0a02ab73a634dd954e88527c72184187cbeee836f023fb73203cfe929`)
- `@layerzerolabs/oapp-evm@0.4.1`: https://registry.npmjs.org/@layerzerolabs/oapp-evm/-/oapp-evm-0.4.1.tgz (SHA-256 `1b8bccf829c464607dd117b83c7ca3a03ac95c60818aed2b8047fcf2bfedfe82`)
- `@layerzerolabs/lz-evm-protocol-v2@3.0.148`: https://registry.npmjs.org/@layerzerolabs/lz-evm-protocol-v2/-/lz-evm-protocol-v2-3.0.148.tgz (SHA-256 `eddf9a1cc9d83ec22fb3537871ed03d69a3bc9bb2105c15e2458aad889bc5fcb`)
- `@openzeppelin/contracts@5.0.2`: https://registry.npmjs.org/@openzeppelin/contracts/-/contracts-5.0.2.tgz (SHA-256 `709a5996fd3fdccc1b3b38c4b87dcafa103b9126b63839f248c4172ba21093fa`)

LayerZero OFT/OApp source: https://github.com/LayerZero-Labs/devtools (packages/oft-evm and packages/oapp-evm). OpenZeppelin source: https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.0.2.

LayerZero license texts: https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/LICENSE-MIT and https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/LICENSE-LZBL-1.2.
