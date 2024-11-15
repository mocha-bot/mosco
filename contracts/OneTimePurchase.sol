// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PurchaseStatus} from "./PurchaseStatus.sol";

contract OneTimePurchase {
    address private owner;

    // Mapping product reference serial to price
    mapping(string => uint256) private productPrices;

    // Mapping to track the purchase status of each buyer for each product
    mapping(address => mapping(string => PurchaseStatus)) private buyerStatus;

    // Mapping to track the amount paid by each buyer
    mapping(address => mapping(string => uint256)) private buyerAmountPaid;

    // Events Purchase
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

    // Events Product Price
    event ProductPriceUpdated(string indexed referenceSerial, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    // Global functions
    function checkPurchaseStatus(
        address _buyer,
        string memory _referenceSerial
    ) public view returns (PurchaseStatus) {
        return buyerStatus[_buyer][_referenceSerial];
    }

    // Buyer functions
    function purchase(string memory _referenceSerial) public payable {
        uint256 currentPrice = productPrices[_referenceSerial];
        require(currentPrice > 0, "OneTimePurchase: product price not set");
        require(
            buyerStatus[msg.sender][_referenceSerial] ==
                PurchaseStatus.Available,
            "OneTimePurchase: product already purchased"
        );
        require(msg.value == currentPrice, "OneTimePurchase: incorrect price");

        buyerStatus[msg.sender][_referenceSerial] = PurchaseStatus.Purchased;
        buyerAmountPaid[msg.sender][_referenceSerial] = msg.value;

        emit PurchaseMade(msg.sender, _referenceSerial, currentPrice);
    }

    function refund(string memory _referenceSerial) public {
        uint256 amountPaid = buyerAmountPaid[msg.sender][_referenceSerial];

        require(amountPaid > 0, "OneTimePurchase: no purchase found");
        require(
            buyerStatus[msg.sender][_referenceSerial] ==
                PurchaseStatus.Purchased,
            "OneTimePurchase: product not yet purchased"
        );

        buyerStatus[msg.sender][_referenceSerial] = PurchaseStatus.Available;
        buyerAmountPaid[msg.sender][_referenceSerial] = 0;

        // Refund the buyer the amount they paid
        payable(msg.sender).transfer(amountPaid);

        emit RefundMade(msg.sender, _referenceSerial, amountPaid);
    }

    // Owner functions
    function withdraw() public {
        require(
            msg.sender == owner,
            "OneTimePurchase: only owner can withdraw"
        );

        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "OneTimePurchase: no balance to withdraw");

        payable(owner).transfer(contractBalance);
        emit WithdrawalMade(owner, contractBalance);
    }

    // Function to set/update the price (only owner can change)
    function setProductPrice(
        string memory _referenceSerial,
        uint256 _newPrice
    ) public {
        require(
            msg.sender == owner,
            "OneTimePurchase: only owner can set the price"
        );
        require(
            _newPrice > 0,
            "OneTimePurchase: price must be greater than zero"
        );
        productPrices[_referenceSerial] = _newPrice;

        emit ProductPriceUpdated(_referenceSerial, _newPrice);
    }

    // Getters
    function getProductPrice(
        string memory _referenceSerial
    ) public view returns (uint256) {
        return productPrices[_referenceSerial];
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getOwner() public view returns (address) {
        return owner;
    }
}
