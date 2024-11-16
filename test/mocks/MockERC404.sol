// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { ERC404 } from "@erc404/ERC404.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC404 is ERC404,Ownable {
    using LibString for uint256;

    constructor(string memory name_, string memory symbol_, uint8 decimals_,address owner_) ERC404(name_, symbol_, decimals_)Ownable(owner_) { }

    function mint(address to_, uint256 value_) public {
        _mintERC20(to_, value_);
    }

    function tokenURI(uint256 id_) public pure override returns (string memory) {
        string memory json = string(
            abi.encodePacked(
                '{"name":"Token #',
                id_.toString(),
                '","description":"An ERC404 token","image":"https://example.com/token/',
                id_.toString(),
                '.png"}'
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function setERC721TransferExempt(address account_, bool value_) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }
}
