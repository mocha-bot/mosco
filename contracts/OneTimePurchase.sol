// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract OneTimePurchase {
  address public owner;
  uint256 public price;
  
  // Reference Serial of the product
  string public referenceSerial;

  event PurchaseMade(address indexed buyer, uint256 amount);
  event Withdrawal(address indexed owner, uint256 amount);

  constructor(uint256 _price, string memory _referenceSerial) {
    require(_price > 0, "OneTimePurchase: price must be greater than zero");
    require(bytes(_referenceSerial).length > 0, "OneTimePurchase: reference serial cannot be empty");

    owner = msg.sender;
    price = _price;
    referenceSerial = _referenceSerial;
  }

  function purchase() public payable {
    require(msg.value == price, "OneTimePurchase: incorrect price");
    payable(owner).transfer(msg.value);
    emit PurchaseMade(msg.sender, msg.value);
  }

  function isPurchased(string memory _referenceSerial) public view returns (bool) {
    require(msg.sender == owner, "OneTimePurchase: only owner can check purchase status");
    return keccak256(abi.encodePacked(_referenceSerial)) == keccak256(abi.encodePacked(referenceSerial));
  }

  function withdraw() public {
    require(msg.sender == owner, "OneTimePurchase: only owner can withdraw");
    uint256 balance = address(this).balance;
    require(balance > 0, "OneTimePurchase: no funds to withdraw");
    payable(owner).transfer(balance);
    emit Withdrawal(owner, balance);
  }
}