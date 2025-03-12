// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@solady/src/tokens/ERC721.sol";

contract MockERC721 is ERC721 {
    string private _name;
    string private _symbol;

    uint256 private _currentTokenId;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function mint(address to) public returns (uint256) {
        uint256 newTokenId = ++_currentTokenId;
        _mint(to, newTokenId);
        return newTokenId;
    }

    function tokenURI(uint256) public view virtual override returns (string memory) {
        return "";
    }
}
