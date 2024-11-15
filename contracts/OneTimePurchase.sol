// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PurchaseStatus} from "./PurchaseStatus.sol";

contract OneTimePurchase {
    address private owner;

    // Amount to be paid for the product
    uint256 private amount;

    // Reference Serial of the product
    string private referenceSerial;

    PurchaseStatus private purchaseStatus;

    // Events
    event PurchaseMade(
        address indexed buyer,
        string indexed referenceSerial,
        uint256 amount
    );

    event RefundMade(
        address indexed buyer,
        string indexed referenceSerial,
        uint256 amount
    );

    event WithdrawalMade(address indexed owner, uint256 amount);

    constructor(uint256 _amount, string memory _referenceSerial) {
        require(
            _amount > 0,
            "OneTimePurchase: price must be greater than zero"
        );
        require(
            bytes(_referenceSerial).length > 0,
            "OneTimePurchase: reference serial cannot be empty"
        );

        owner = msg.sender;
        amount = _amount;
        referenceSerial = _referenceSerial;
        purchaseStatus = PurchaseStatus.Available;
    }

    // Global function to check purchase status
    function checkPurchaseStatus() public view returns (PurchaseStatus) {
        return purchaseStatus;
    }

    // Buyer functions
    function purchase() public payable {
        require(
            purchaseStatus == PurchaseStatus.Available,
            "OneTimePurchase: product is not available"
        );
        require(msg.value == amount, "OneTimePurchase: incorrect price");

        purchaseStatus = PurchaseStatus.Purchased;
        emit PurchaseMade(msg.sender, referenceSerial, amount);
    }

    function refund() public {
        require(
            purchaseStatus == PurchaseStatus.Purchased,
            "OneTimePurchase: product not yet purchased"
        );
        require(
            address(this).balance >= amount,
            "OneTimePurchase: insufficient balance"
        );

        purchaseStatus = PurchaseStatus.Available;
        payable(msg.sender).transfer(amount);

        emit RefundMade(msg.sender, referenceSerial, amount);
    }

    // Owner functions
    function withdraw() public {
        require(
            msg.sender == owner,
            "OneTimePurchase: only owner can withdraw"
        );
        require(
            purchaseStatus == PurchaseStatus.Purchased,
            "OneTimePurchase: product not yet purchased"
        );

        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "OneTimePurchase: no balance to withdraw");

        purchaseStatus = PurchaseStatus.Withdrawn;
        payable(owner).transfer(contractBalance);

        emit WithdrawalMade(owner, contractBalance);
    }

    // Utility functions
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getOwner() public view returns (address) {
        return owner;
    }
}
