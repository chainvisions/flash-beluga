// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC3156FlashLender, IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156.sol";
import {Governable} from "./lib/Governable.sol";

contract Wrapper is ERC20("Flash Beluga Wrapper", "fBELUGA"), IERC3156FlashLender, Governable {
    using SafeERC20 for IERC20;

    /// @dev Underlying token of the wrapper.
    address public underlying;
    
    /// @dev Fee for flashloans.
    uint256 public flashloanFee;

    /// @dev Buffer for flashloans.
    uint256 public flashBuffer;

    /// @dev Return value for flashloans, as part of the ERC3156 standard.
    bytes32 internal constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    modifier onlyEOA {
        require(msg.sender == tx.origin, "Wrapper: Caller is not an EOA");
        _;
    }

    constructor(
        address _store, 
        address _underlying,
        uint256 _fee
    ) Governable(_store) {
        underlying = _underlying;
        flashloanFee = _fee;
    }

    /// @dev Wraps BELUGA tokens in the wrapper.
    /// @param _amount Amount of BELUGA to wrap.
    function wrap(uint256 _amount) external {
        _wrap(msg.sender, msg.sender, _amount);
    }

    /// @dev Wraps BELUGA tokens for another account.
    /// @param _for Receiver of the wrapper deposit.
    /// @param _amount Amount to deposit into the wrapper.
    function wrapFor(address _for, uint256 _amount) external {
        _wrap(msg.sender, _for, _amount);
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

    /// @dev Flash borrows BELUGA in the wrapper.
    /// @param _receiver The receiver of the flashloan.
    /// @param _token Token to borrow, should be BELUGA.
    /// @param _amount Amount of tokens to borrow.
    /// @param _data A datafield that is passed to the receiver.
    /// @return If the flashloan was successful.
    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external override returns (bool) {
        require(_amount <= maxFlashLoan(underlying));
        uint256 fee = flashFee(_token, _amount);
        IERC20(underlying).safeTransfer(address(_receiver), _amount);
        require(
            _receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) == _RETURN_VALUE,
            "Wrapper: Invalid return value"
        );
        uint256 currentAllowance = IERC20(underlying).allowance(address(_receiver), address(this));
        require(currentAllowance >= _amount + fee, "Wrapper: Insufficient allowance");
        IERC20(underlying).safeTransferFrom(address(_receiver), address(this), _amount + fee);
        return true;
    }

    /// @dev Sets the fee for flashloans.
    /// @param _fee Fee for flashloans, in basis points.
    function setFlashloanFee(uint256 _fee) public onlyGovernance {
        flashloanFee = _fee;
    }

    /// @dev Sets the buffer for the max flashloan amount.
    /// @param _flashBuffer Buffer in basis points.
    function setFlashloanBuffer(uint256 _flashBuffer) public onlyGovernance {
        flashBuffer = _flashBuffer;
    }

    /// @dev Fetches the total amount of tokens in the wrapper.
    /// @return The amount of BELUGA in the wrapper.
    function totalTokensInWrapper() public view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    /// @dev Fetches the share price of fBELUGA.
    /// @return The price of 1 fBELUGA in BELUGA.
    function getPricePerFullShare() public view returns (uint256) {
        return (totalTokensInWrapper() / totalSupply());
    }

    /// @dev Fetches how much BELUGA a holder's fBELUGA is worth.
    /// @param _holder The holder to fetch the value of.
    /// @return Value of the holder's fBELUGA.
    function totalValueOfHolder(address _holder) public view returns (uint256) {
        return (balanceOf(_holder) * getPricePerFullShare());
    }

    /// @dev Fetches the max amount of tokens that can be borrowed.
    /// @param _token The token to fetch the max of.
    /// @return The maximum amount of tokens.
    function maxFlashLoan(address _token) public view override returns (uint256) {
        return _token == underlying ? (totalTokensInWrapper() * flashBuffer) / 10000 : 0;
    }

    /// @dev Fetches the fee for a flashloan.
    /// @param _token Token for the flashloan, should be BELUGA.
    /// @param _amount Amount to borrow in the flashloan.
    /// @return The fee for the flashloan.
    function flashFee(address _token, uint256 _amount) public view override returns (uint256) {
        require(_token == underlying, "Wrapper: The wrapper only supports BELUGA");
        uint256 fee = (_amount * flashloanFee) / 10000;
        return fee;
    }
    
    function _wrap(address _from, address _to, uint256 _amount) internal onlyEOA {
        require(_amount > 0, "Wrapper: Cannot wrap 0");
        uint256 toMint = totalSupply() == 0
            ? _amount
            : (_amount * totalSupply()) / totalTokensInWrapper();
        _mint(_to, toMint);
        IERC20(underlying).safeTransferFrom(_from, address(this), _amount);
    }
}