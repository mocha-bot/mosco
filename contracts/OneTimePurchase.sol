// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {PurchaseStatus} from "./constant/PurchaseStatus.sol";
import {
    REFUND_PERIOD,
    REFUND_FEE_PERCENTAGE,
    MAX_NAME_LENGTH
} from "./constant/Constant.sol";

contract OneTimePurchase is Ownable, ReentrancyGuard {
    struct Product {
        bytes32 referenceSerial;
        string name;
        uint256 price;
        bool isRegistered;
    }

    struct PurchaseItem {
        uint256 amount;
        uint256 timestamp;
        uint256 maxRefundTimestamp;
        bytes32 referenceSerial;
        PurchaseStatus status;
    }

    struct Purchase {
        mapping(bytes32 => PurchaseItem) purchaseItems;
        uint256 totalPurchases;
    }

    // Mappings for products and purchases
    mapping(bytes32 => Product) private products;
    mapping(address => Purchase) private purchases;

    bytes32[] private productReferenceSerials;

    // Events for product purchase, refund, and owner withdrawals
    event PurchaseMade(
        address indexed buyer,
        bytes32 indexed referenceSerial,
        uint256 amount
    );
    event RefundMade(
        address indexed buyer,
        bytes32 indexed referenceSerial,
        uint256 amount
    );
    event WithdrawalMade(address indexed owner, uint256 amount);

    // Events for product updates
    event ProductUpdated(bytes32 indexed referenceSerial, string name);

    // Events for product removed
    event ProductRemoved(bytes32 indexed referenceSerial);

    constructor() Ownable(msg.sender) {}

    // Global functions
    function getPurchasedItem(
        address buyer,
        bytes32 referenceSerial
    ) external view returns (PurchaseItem memory) {
        return purchases[buyer].purchaseItems[referenceSerial];
    }

    function hasPurchased(
        address buyer,
        bytes32 referenceSerial
    ) external view returns (bool) {
        return
            purchases[buyer].purchaseItems[referenceSerial].status ==
            PurchaseStatus.Purchased;
    }

    // Buyer functions
    function purchase(bytes32 referenceSerial) external payable nonReentrant {
        Product storage product = products[referenceSerial];
        require(product.price > 0, "product price not set");

        PurchaseItem storage purchaseItem = purchases[msg.sender].purchaseItems[
            referenceSerial
        ];
        require(
            purchaseItem.status != PurchaseStatus.Purchased,
            "product already purchased"
        );

        uint256 currentPrice = product.price;
        require(msg.value == currentPrice, "incorrect price");

        purchaseItem.referenceSerial = referenceSerial;
        purchaseItem.amount = currentPrice;
        purchaseItem.status = PurchaseStatus.Purchased;
        purchaseItem.timestamp = block.timestamp;
        purchaseItem.maxRefundTimestamp = block.timestamp + REFUND_PERIOD;

        purchases[msg.sender].totalPurchases += 1;
        emit PurchaseMade(msg.sender, referenceSerial, currentPrice);
    }

    function refund(bytes32 referenceSerial) external nonReentrant {
        PurchaseItem storage purchaseItem = purchases[msg.sender].purchaseItems[
            referenceSerial
        ];
        uint256 amountPaid = purchaseItem.amount;

        uint256 refundFee = 0;
        if (amountPaid > 0) {
            refundFee = (amountPaid * REFUND_FEE_PERCENTAGE) / 100;
        }

        uint256 refundAmount = amountPaid - refundFee;

        require(amountPaid > 0, "no purchase found");
        require(
            purchaseItem.status == PurchaseStatus.Purchased,
            "product not yet purchased"
        );
        require(
            block.timestamp <= purchaseItem.maxRefundTimestamp,
            "refund period has ended"
        );

        purchaseItem.status = PurchaseStatus.Refunded;
        purchaseItem.amount = 0;
        purchaseItem.maxRefundTimestamp = 0;
        purchaseItem.timestamp = 0;
        purchaseItem.referenceSerial = bytes32(0);

        delete purchases[msg.sender].purchaseItems[referenceSerial];
        purchases[msg.sender].totalPurchases -= 1;
        if (purchases[msg.sender].totalPurchases == 0) {
            delete purchases[msg.sender];
        }

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "refund transfer failed");

        emit RefundMade(msg.sender, referenceSerial, refundAmount);
    }

    receive() external payable {
        revert("Direct transfers is not allowed");
    }

    fallback() external payable {
        revert("Direct transfers is not allowed");
    }

    // Owner functions
    function getAllProducts()
        external
        view
        onlyOwner
        returns (Product[] memory)
    {
        uint256 length = productReferenceSerials.length;
        Product[] memory result = new Product[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = products[productReferenceSerials[i]];
        }
        return result;
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(
            amount > 0,
            "amount must be greater than zero"
        );
        require(
            contractBalance >= amount,
            "insufficient contract balance"
        );

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "withdrawal transfer failed");

        emit WithdrawalMade(msg.sender, amount);
    }

    function updateProduct(
        bytes32 referenceSerial,
        string memory name,
        uint256 price
    ) public onlyOwner {
        require(price > 0, "price must be greater than zero");
        require(
            referenceSerial != bytes32(0),
            "reference serial must be filled"
        );
        require(
            bytes(name).length > 0,
            "name must not be empty"
        );
        require(
            bytes(name).length <= MAX_NAME_LENGTH,
            "name too long"
        );

        bool isNewProduct = !products[referenceSerial].isRegistered;

        products[referenceSerial] = Product({
            referenceSerial: referenceSerial,
            name: name,
            price: price,
            isRegistered: true
        });

        if (isNewProduct) {
            productReferenceSerials.push(referenceSerial);
        }

        emit ProductUpdated(referenceSerial, name);
    }

    function removeProduct(bytes32 referenceSerial) external onlyOwner {
        require(
            products[referenceSerial].isRegistered,
            "product not found"
        );
        delete products[referenceSerial];

        for (uint256 i = 0; i < productReferenceSerials.length; i++) {
            if (productReferenceSerials[i] != referenceSerial) continue;

            productReferenceSerials[i] = productReferenceSerials[
                productReferenceSerials.length - 1
            ];
            productReferenceSerials.pop();
            break;
        }

        emit ProductRemoved(referenceSerial);
    }

    function getBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    // Getters
    function getProduct(
        bytes32 referenceSerial
    ) external view returns (Product memory) {
        return products[referenceSerial];
    }
}
