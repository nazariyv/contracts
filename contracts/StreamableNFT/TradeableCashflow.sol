
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./RedirectAll.sol";

contract TradeableCashflow is ERC721, RedirectAll {

  event NewFace(
    address indexed owner,
    uint256 indexed tokenId,
    string tokenURI
  );

  constructor(
    address owner,
    string memory _name,
    string memory _symbol,
    ISuperfluid host,
    IConstantFlowAgreementV1 cfa,
    ISuperToken acceptedToken
  )
    public
    ERC721("TradeableCashflow", "SFC")
    RedirectAll(host, cfa, acceptedToken, owner)
  {}

  // before mint, burn, transfer, this gets called
  // i.e. the receiver of the stream changes
  // the receiver of the stream is always the LENDER
  // albeit the NFT being with the borrower.
  // When the NFT is transfered back to the owner,
  // the receiver is set to address(0)
  function _beforeTokenTransfer(
    address, /*from*/
    address to,
    uint256 /*tokenId*/
  ) internal override {
    _changeReceiver(to);
  }
}