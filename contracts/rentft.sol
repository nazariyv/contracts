// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../node_modules/@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./utils/ProxyFactory.sol";
import "./utils/OwnableUpgradeSafe.sol";
import "./utils/ContextUpgradeSafe.sol";
import "./utils/Initializable.sol";
import "./interfaces/ILendingPoolAddressProvider.sol";
import "./interfaces/ILendingPoolCore.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/AToken.sol";


contract InterestCalculatorProxy is Initializable, OwnableUpgradeSafe {
  using  SafeERC20 for ERC20;
  event Initialized(address indexed thisAddress);
  address public rentft;

  // proxy admin would be the owner to prevent in fraud cases where the borrower
  // doesn't return the nft back
  function initialize(address _owner, address _rentft) public initializer {
    OwnableUpgradeSafe.__Ownable_init();
    OwnableUpgradeSafe.transferOwnership(_owner);
    rentft = _rentft;
    emit Initialized(address(this));
  }
  
  function deposit(address _reserve, address _lendingPool, address _lendingPoolCore) public {
    uint reserveBalance = ERC20(_reserve).balanceOf(address(this));
    ERC20(_reserve).approve(_lendingPoolCore, reserveBalance);
    ILendingPool(_lendingPool).deposit(_reserve, reserveBalance, 0);
  }
  
  // allow rentft to withdraw from aave
  function withdraw(address _aToken) public returns(uint256) {
      require(msg.sender == rentft, "Not Rentft");
      
      uint256 daiBalance = getBalance(_aToken);
      
      // withdraw dai from aDai
      AToken(_aToken).redeem(daiBalance);
      
      ERC20(_aToken).safeTransfer(rentft, daiBalance);
      
      return daiBalance;
  }

  function getBalance(address _reserve) public view returns (uint256) {
    // All calculations to be done in the parent contract
    return AToken(_reserve).balanceOf(address(this));
  }
}

contract Rentft is
  ProxyFactory,
  ChainlinkClient,
  ReentrancyGuard
{
  // using SafeMath for uint256;
  using SafeERC20 for ERC20;

  struct Asset {
    address owner;
    address borrower;
    uint256 duration;    // should be unix again to avoid decimal issues
    uint256 borrowedAt;  // borrowed time to be verifed by returning
    uint256 nftPrice;
    uint256 collateral;  // for security
  }

  // proxy details
  // owner => borrower => proxy
  mapping(address => mapping(address => address)) public proxyInfo;

  // nft address => token id => asset info struct
  mapping(address => mapping(uint256 => Asset)) public assets;

  uint256 private nftPrice;
  address private oracle;
  bytes32 private jobId;
  uint256 private chainlinkFee;
  // this fee is added on top of the collateral for each hold day of the NFT.
  // This is used to cancel out any potential swings in the price of the NFT
  // denoted in bps (basis points). 1% is 100 bps. 0.1% is 10 bps and
  // equivalently 0.01% is 1 bps. The mechanism for computing the rent will
  // change in the future, to be more efficient and meaningful
  uint256 public collateralDailyFee = 100;
  address public daiAddress = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
  address public aDaiAddress = 0x58AD4cB396411B691A9AAb6F74545b2C5217FE6a;

  ILendingPoolAddressesProvider public lendingPoolAddressProvider;
  ILendingPool public lendingPool;
  ILendingPoolCore public lendingPoolCore;

  /**
   * Network: Kovan
   * Oracle: Chainlink - 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
   * Job ID: Chainlink - 29fa9aa13bf1468788b7cc4a500a45b8
   * Link: 0xa36085F69e2889c224210F603D836748e7dC0088
   * Fee: 0.1 LINK
   */
  // provide aave address provider for the network you are working on
  // get all aave related addresses through addressesProvider state var
  // get all aToken reserve addresses through the core state var
  constructor(ILendingPoolAddressesProvider _lendingPoolAddressProvider) public {
    setPublicChainlinkToken();
    oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
    jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
    chainlinkFee = 0.1 * 10**18; // 0.1 LINK
    // do we need this at the moment  ?
    lendingPoolAddressProvider =_lendingPoolAddressProvider;
    lendingPool = ILendingPool(lendingPoolAddressProvider.getLendingPool());
    lendingPoolCore = ILendingPoolCore(lendingPoolAddressProvider.getLendingPoolCore());
  }

  // function to list the nft on the platform
  // url will be the api endpoint to fetch nft price
  function addProduct(
    address nftAddress,
    uint256 nftId,
    uint256 duration,
    string calldata _url
  ) external {
    require(nftAddress != address(0), "Invalid NFT Address");
    
    fetchNFTPrice(_url);

    // need to verify whether the nftPrice will have the latest value
    assets[nftAddress][nftId] = Asset(
      msg.sender,
      address(0),
      duration,
      0,
      nftPrice,
      0
    );
    
    // transfer nft to this contract
    ERC721(nftAddress).transferFrom(msg.sender, address(this), nftId);
  }

   /**
   * @dev calculates the total collateral price of the NFT. Imagine virtual museums that rent out
   * the NFTs of the artists for some time. Therefore, there is a potential for reputation
   * here. If the borrower has consistently good renting track-record, they will get more
   * favourable quotes
   * @param _duration number of days that the user wishes to rent out the NFT for. 1 means 1 day
   * @return the total collateral + fee the borrower has to put up
   **/
  function calculateCollateral(
    address _nft,
    uint256 _tokenId,
    uint256 _duration
  ) public view returns (uint256) {
    // ! TODO: need to ensure that this nftPrice is relevant, and is not old
    // can we invoke chainlink price update here before computing the rentPrice?
    // collateral = _nft_price * ((collateralDailyFee) ** _duration)
    // collateral (with our service fee) = rentPrice * ourFee
    // ! this must always be populated, otherwise an error will be thrown
    // * interest compounding
    uint256 basePrice = assets[_nft][_tokenId].nftPrice;
    uint256 collateral = ((basePrice).add(basePrice.mul(collateralDailyFee).div(10000))).mul(_duration);
    // this though returns price in ETH
    // we need an ability to convert it into whatever
    return collateral;
  }

  // to rent the contract:
  // 1. the borrower must have paid the indicated collateral
  // validations:
  // 1. the borrower can't be borrowing the borrowed nft
  // (this check also ensures that the borrower is not the
  // owner & that the borrower isn't borrowing what he already borrowed)
  function rent(
    address _borrower,
    uint256 _duration,
    address _nft,
    uint256 _tokenId,
    string calldata _url
    ) external nonReentrant {
    require(assets[_nft][_tokenId].duration > 0, "could not find an NFT");
    
    address owner = assets[_nft][_tokenId].owner;
    fetchNFTPrice(_url);
    assets[_nft][_tokenId].nftPrice = nftPrice;
    // ! we only need DAI here to begin with
    // require(msg.value > 0, "you need to pay the collateral");
    uint256 collateral = calculateCollateral(_nft, _tokenId, _duration);

    // ! will fail if the msg.sender hasn't approved us as the spender of their ERC20 tokens
    transferToProxy(
      daiAddress,
      msg.sender,
      collateral,
      proxyInfo[owner][_borrower]
    );
    // deposit to aave
    InterestCalculatorProxy(proxyInfo[owner][_borrower]).deposit(daiAddress, address(lendingPool), address(lendingPoolCore));
    
    // set asset vars
    assets[_nft][_tokenId].borrower = _borrower;
    assets[_nft][_tokenId].borrowedAt = now;
    assets[_nft][_tokenId].collateral = collateral;
    
    // transfer nft to borrower
    ERC721(_nft).transferFrom(address(this), _borrower, _tokenId);
  }
  
  // called by borrower
  // !! base url must be stored in contract, borrower might provide fake one here
  // user won't provide the usrl since it has dynamic parameters we wouuld be constructing it on the js end
  // NOTE -> there won't be a case where the borrower will recieve 0 as the amount it has to be collateral deposited - current price and interest calculations on top of that
  function returnNFT(
    address _nft,
    uint256 _tokenId,
    string calldata _url
  ) external {
      require(assets[_nft][_tokenId].duration > 0, "could not find an NFT");
      require(assets[_nft][_tokenId].borrower == msg.sender, "Not Borrower");
      // check (now-borrowedAt) <= duration in secs
      uint256 durationInDays = now.sub(assets[_nft][_tokenId].borrowedAt).div(86400);
      require(durationInDays <= assets[_nft][_tokenId].duration, "Duration exceeded");
      
      address owner = assets[_nft][_tokenId].owner;
      uint256 collateralAvailable = assets[_nft][_tokenId].collateral;
      
      // redeem aDai to Dai in Proxy
      uint256 daiReceived = InterestCalculatorProxy(proxyInfo[owner][msg.sender]).withdraw(aDaiAddress);
      // calculate aave interest
      uint256 interest = daiReceived.sub(collateralAvailable);
      // split interest to both users
      uint256 ownerPayout = interest.div(2);
      uint256 borrowerPayout = interest.div(2);
      
      // get current nft price
      fetchNFTPrice(_url);
      require(nftPrice != 0, "Invalid NFT Price");
      assets[_nft][_tokenId].nftPrice = nftPrice;
      // calculate latest collateral
      // note => the price here is the latest price removed the current price var due to stack deep error
      uint256 latestCollateralAmount = calculateCollateral(_nft, _tokenId, durationInDays);
      // rent calculation based on latest price
      uint256 calculatedRent = nftPrice.mul(collateralDailyFee).div(10000).mul(durationInDays);
      if (latestCollateralAmount > collateralAvailable) {
          uint256 extra = latestCollateralAmount.sub(collateralAvailable);
          borrowerPayout = (borrowerPayout.add((collateralAvailable.sub(nftPrice)).sub(calculatedRent))).sub(extra);
          ownerPayout = ownerPayout.add(extra);
      } else {
          uint256 extra = collateralAvailable.sub(latestCollateralAmount);
          borrowerPayout = (borrowerPayout.add((collateralAvailable.sub(nftPrice)).sub(calculatedRent))).add(extra);
          ownerPayout = ownerPayout.sub(extra);
      }

      // send nft to owner
      ERC721(_nft).transferFrom(msg.sender, owner, _tokenId);
      
      //send payout amounts to both
      ERC20(daiAddress).safeTransfer(owner, ownerPayout);
      ERC20(daiAddress).safeTransfer(msg.sender, borrowerPayout);
      

      // set assets params to null
      assets[_nft][_tokenId].duration = 0;
  }
  
  /**
   * @dev transfers an amount from a user to the destination proxy address where it
   * subsequently gets deposited into Aave
   * @param _reserve the address of the reserve where the amount is being transferred
   * @param _user the address of the user from where the transfer is happening
   * @param _amount the amount being transferred
   **/
  function transferToProxy(
    address _reserve,
    address payable _user,
    uint256 _amount,
    address _proxy
  ) private {
      require(
        msg.value == 0,
        "User is sending ETH along with the ERC20 transfer."
      );
      // ! our contract should be approved to move his ERC20 funds
      ERC20(_reserve).safeTransferFrom(_user, _proxy, _amount);
  }

  // create the proxy contract for managing interest when a borrower rents it out
  function createProxy(address _owner, address _borrower) internal {
    bytes memory _payload = abi.encodeWithSignature(
      "initialize(address)",
      _owner
    );
    // Deploy proxy
    // for testing the address of the proxy contract which will
    // be used to redirect interest will come here
    address _intermediate = deployMinimal(oracle, _payload);
    // user address is just recorded for tracking the proxy for the particular pair
    // TODO: need to test this for same owner but different user
    proxyInfo[_owner][_borrower] = _intermediate;
  }

  // check whether the proxy contract exists or not for a owner-borrower pair
  function getProxy(address _owner, address _borrower)
    internal
    view
    returns (address)
  {
    return proxyInfo[_owner][_borrower];
  }
  
  function fetchNFTPrice(string memory _url) internal {
      Chainlink.Request memory request = buildChainlinkRequest(
      jobId,
      address(this),
      this.fulfill.selector
    );

    // Set the URL to perform the GET request on
    request.add("get", _url);

    // Set the path to find the desired data in the API response, where the response format is:
    request.add("path", "last_sale.payment_token.usd_price");

    // Multiply the result by 100 to remove decimals
    request.addInt("times", 1000000000000000000);

    // Sends the request
    sendChainlinkRequestTo(oracle, request, chainlinkFee);
  }

  /**
   * Receive the price response in the form of uint256
   */
  function fulfill(bytes32 _requestId, uint256 _price)
    public
    recordChainlinkFulfillment(_requestId)
  {
    nftPrice = _price;
  }
}
