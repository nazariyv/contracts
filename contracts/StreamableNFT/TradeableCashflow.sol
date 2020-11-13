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

  // uint private once = 0;
  // address owner;

  constructor(
    address _owner,
    string memory _name,
    string memory _symbol,
    ISuperfluid _host,
    IConstantFlowAgreementV1 _cfa,
    ISuperToken _acceptedToken
  ) ERC721(_name, _symbol) RedirectAll(_host, _cfa, _acceptedToken, _owner) {
    // owner = _owner;
    _mint(_owner, 1);
  }

  // ! TODO: hack. The factory wouldn't deploy. I suspect it is due to the gas block limit
  // function mint() external {
  //   require(once == 0, "not allowed");
  //   _mint(owner, 1);
  // }

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
