// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import {PurchaseStatus} from "./PurchaseStatus.sol";
import {RefundPeriod} from "./constant/Constant.sol";

contract OneTimePurchase is Ownable {
    struct Product {
        string referenceSerial;
        string name;
        string description;
        uint256 price;
        bool isRegistered;
    }

    struct PurchaseItem {
        string referenceSerial;
        uint256 amount;
        PurchaseStatus status;
        uint256 timestamp;
        uint256 maxRefundTimestamp;
    }

    struct Purchase {
        mapping(string => PurchaseItem) purchaseItems;
        uint256 totalPurchases;
    }

    // Mappings for products and purchases
    mapping(string => Product) private products;
    mapping(address => Purchase) private purchases;

    string[] private productReferenceSerials;

    // Events for product purchase, refund, and owner withdrawals
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

    // Events for product updates
    event ProductUpdated(string indexed referenceSerial, string name);

    constructor() Ownable(msg.sender) {}

    // Global functions
    function getPurchasedItem(
        address buyer,
        string memory referenceSerial
    ) public view returns (PurchaseItem memory) {
        return purchases[buyer].purchaseItems[referenceSerial];
    }

    // Buyer functions
    function purchase(string memory referenceSerial) public payable {
        Product storage product = products[referenceSerial];
        require(product.price > 0, "OneTimePurchase: product price not set");

        PurchaseItem storage purchaseItem = purchases[msg.sender].purchaseItems[
            referenceSerial
        ];
        require(
            purchaseItem.status != PurchaseStatus.Purchased &&
                purchaseItem.status != PurchaseStatus.Withdrawn,
            "OneTimePurchase: product already purchased"
        );

        uint256 currentPrice = product.price;
        require(msg.value == currentPrice, "OneTimePurchase: incorrect price");

        purchaseItem.referenceSerial = referenceSerial;
        purchaseItem.amount = currentPrice;
        purchaseItem.status = PurchaseStatus.Purchased;
        purchaseItem.timestamp = block.timestamp;
        purchaseItem.maxRefundTimestamp = block.timestamp + RefundPeriod;

        purchases[msg.sender].totalPurchases += 1;
        emit PurchaseMade(msg.sender, referenceSerial, currentPrice);
    }

    function refund(string memory referenceSerial) public {
        PurchaseItem storage purchaseItem = purchases[msg.sender].purchaseItems[
            referenceSerial
        ];
        uint256 amountPaid = purchaseItem.amount;

        require(amountPaid > 0, "OneTimePurchase: no purchase found");
        require(
            purchaseItem.status == PurchaseStatus.Purchased,
            "OneTimePurchase: product not yet purchased"
        );
        require(
            block.timestamp <= purchaseItem.maxRefundTimestamp,
            "OneTimePurchase: refund period has ended"
        );

        purchaseItem.status = PurchaseStatus.Refunded;
        payable(msg.sender).transfer(amountPaid);
        emit RefundMade(msg.sender, referenceSerial, amountPaid);
    }

    // Owner functions
    function withdraw(uint256 amount) public onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(
            amount > 0,
            "OneTimePurchase: amount must be greater than zero"
        );
        require(
            contractBalance >= amount,
            "OneTimePurchase: insufficient contract balance"
        );

        payable(msg.sender).transfer(amount);
        emit WithdrawalMade(msg.sender, amount);
    }

    function updateProduct(
        string memory referenceSerial,
        string memory name,
        string memory description,
        uint256 price
    ) public onlyOwner {
        require(price > 0, "OneTimePurchase: price must be greater than zero");
        require(
            bytes(referenceSerial).length > 0,
            "OneTimePurchase: reference serial must not be empty"
        );
        require(
            bytes(name).length > 0,
            "OneTimePurchase: name must not be empty"
        );

        products[referenceSerial] = Product({
            referenceSerial: referenceSerial,
            name: name,
            description: description,
            price: price,
            isRegistered: true
        });

        emit ProductUpdated(referenceSerial, name);
    }

    function getBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    // Getters
    function getProduct(
        string memory referenceSerial
    ) public view returns (Product memory) {
        return products[referenceSerial];
    }
}
