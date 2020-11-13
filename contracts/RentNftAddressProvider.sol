// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./configuration/AddressStorage.sol";

contract RentNftAddressProvider is Ownable, AddressStorage {
  uint8 private networkId;

  constructor(uint8 _networkId) {
    networkId = _networkId;
  }

  function getToken(bytes calldata token) public view returns (address) {
    return getAddress(keccak256(abi.encodePacked(token, networkId)));
  }

  function setToken(bytes calldata token, address tokenAddress)
    public
    onlyOwner
  {
    _setAddress(keccak256(abi.encodePacked(token, networkId)), tokenAddress);
  }
}
