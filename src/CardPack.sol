// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.26;

// import { ERC404 } from "@erc404/ERC404.sol";
// contract CardPack is ERC404 {
//     struct PackAttributes {
//         uint8 rarity;
//         uint16 season;
//         bool isSpecial;
//         uint32 createdAt;
//     }
    
//     mapping(uint256 => PackAttributes) public packAttributes;
    
//     constructor() ERC404(
//         "Mystery Card Pack", 
//         "PACK",
//         18
//     ) {}
    
//     function _beforeTokenTransfer(uint256 tokenId) internal {
//         if(packAttributes[tokenId].createdAt == 0) {
//             packAttributes[tokenId] = PackAttributes({
//                 // rarity: _determineRarity(),
//                 rarity: 1,
//                 season: uint16(block.timestamp / 30 days),
//                 // isSpecial: _isSpecialPeriod(),
//                 isSpecial: false,
//                 createdAt: uint32(block.timestamp)
//             });
//         }
//     }
// }