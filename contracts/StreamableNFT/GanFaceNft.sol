// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GanFaceNft is ERC721, ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private __tokenIds;
  address public currentOwner;

  constructor(address _owner, string memory _tokenURI) ERC721("GANFACE", "GF") {
    awardGanFace(_owner, _tokenURI);
  }

  function awardGanFace(address _minter, string memory _tokenURI)
    internal
    nonReentrant
    returns (uint256)
  {
    __tokenIds.increment();

    uint256 newItemId = __tokenIds.current();
    _mint(_minter, newItemId);
    _setTokenURI(newItemId, _tokenURI);

    currentOwner = _minter;

    return newItemId;
  }

  modifier onlyOwner() {
    require(msg.sender == currentOwner, "you cannot update");
    _;
  }
}
