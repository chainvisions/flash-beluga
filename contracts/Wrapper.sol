// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./lib/Governable.sol";

contract Wrapper is ERC20("Flash Beluga Wrapper", "fBELUGA"), Governable {
    using SafeERC20 for IERC20;

    /// @dev Underlying token of the wrapper.
    address public underlying;
    
    /// @dev Fee for flashloans.
    uint256 public flashloanFee;

    /// @dev Buffer for flashloans.
    uint256 public flashBuffer;

    modifier onlyEOA {
        require(msg.sender == tx.origin, "Wrapper: Caller is not an EOA");
        _;
    }

    constructor(address _store) Governable(_store) {}

    /// @dev Wraps BELUGA tokens in the wrapper.
    /// @param _amount Amount of BELUGA to wrap.
    function wrap(uint256 _amount) external onlyEOA {
        require(_amount > 0, "Wrapper: Cannot wrap 0");
        uint256 toMint = totalSupply() == 0
            ? _amount
            : (_amount * totalSupply()) / totalTokensInWrapper();
        _mint(msg.sender, toMint);
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @dev Unwraps BELUGA from the wrapper.
    /// @param _amount Amount of BELUGA to unwrap (in fBELUGA).
    function unwrap(uint256 _amount) external onlyEOA {
        require(totalSupply() > 0, "Wrapper: The wrapper has no shares");
        require(_amount > 0, "Wrapper: Cannot unwrap 0");
        uint256 sharesToTokens = (totalTokensInWrapper() * _amount) / totalSupply();
        _burn(msg.sender, _amount);
        IERC20(underlying).safeTransfer(msg.sender, sharesToTokens);
    }

    /// @dev Fetches the total amount of tokens in the wrapper.
    /// @return The amount of BELUGA in the wrapper.
    function totalTokensInWrapper() public view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    /// @dev Fetches the max amount of tokens that can be borrowed.
    /// @param _token The token to fetch the max of.
    /// @return The maximum amount of tokens.
    function maxFlashloan(address _token) public view returns (uint256) {
        return _token == underlying ? (totalTokensInWrapper() * flashBuffer) / 10000 : 0;
    }

    /// @dev Fetches the fee for a flashloan.
    /// @param _token Token for the flashloan, should be BELUGA.
    /// @param _amount Amount to borrow in the flashloan.
    /// @return The fee for the flashloan.
    function flashFee(address _token, uint256 _amount) public view returns (uint256) {
        require(_token == underlying, "Wrapper: The wrapper only supports BELUGA");
        uint256 fee = (_amount * flashloanFee) / 10000;
        return fee;
    }

}