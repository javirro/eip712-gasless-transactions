// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;


/**
 * @title ExampleSmartContract
 * @dev A simple smart contract that allows updating a stored value. This contract is used to demonstrate meta-transactions.
 */
contract ExampleSmartContract {
    uint256 public value;

    event ValueUpdated(address indexed updater, uint256 newValue);

    function updateValue(uint256 newValue) external {
        value = newValue;
        emit ValueUpdated(msg.sender, newValue);
    }
}