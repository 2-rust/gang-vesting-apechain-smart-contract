// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@solady/src/tokens/ERC20.sol";

/// @title Gang Token
/// @notice ERC20 Token
/// @author Rookmate (@0xRookmate)
contract Gang is ERC20 {
    // TODO: CHECK FINAL DECISION WITH THE TEAM
    string private _name = "Gang Token";
    string private _symbol = "GANG";
    uint8 private immutable _decimals = 18;
    uint256 public immutable MAX_SUPPLY = 1_000_000_000 * (10 ** 18);

    constructor() {
        _mint(msg.sender, MAX_SUPPLY);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
