// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GanFaceNft is ERC721, ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private __tokenIds;
  address[] public streams;
  address public currentOwner;

  event NewFace(
    address indexed owner,
    uint256 indexed tokenId,
    string tokenURI
  );

  constructor() public ERC721("GANFACE", "GF") {}

  function awardGanFace(address _minter, string memory _tokenURI)
    public
    nonReentrant
    returns (uint256)
  {
    __tokenIds.increment();

    uint256 newItemId = __tokenIds.current();
    _mint(_minter, newItemId);
    _setTokenURI(newItemId, _tokenURI);

    currentOwner = _minter;
    emit NewFace(_minter, newItemId, _tokenURI);

    return newItemId;
  }

  // on lend, this gets called to update the list of associated
  // contract streams
  // on return, a 0 address is passed to pop from the stack
  // todo: very simplistic and can be gamed
  function updateStreams(address newAddress) internal onlyOwner {
    if (newAddress == address(0)) {
      delete streams[streams.length - 1];
    } else {
      streams.push(newAddress);
    }
  }

  modifier onlyOwner() {
    require(msg.sender == currentOwner, "you cannot update");
    _;
  }
}
