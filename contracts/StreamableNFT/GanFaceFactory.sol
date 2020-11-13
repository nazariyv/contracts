// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import {
  ISuperfluid,
  ISuperToken,
  ISuperApp,
  SuperAppDefinitions,
  ISuperAgreement
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {
  IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import "./GanFaceNft.sol";

contract GanFaceFactory {
  event NewFace(
    address indexed owner,
    address indexed nft,
    uint256 indexed tokenId,
    string tokenURI
  );

  function newFace(address _owner, string calldata _tokenURI)
    public
    returns (address)
  {
    GanFaceNft gan = new GanFaceNft(_owner, _tokenURI);
    emit NewFace(_owner, address(gan), 1, _tokenURI);
    return address(gan);
  }
}
