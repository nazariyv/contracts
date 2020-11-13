const RentNftAddressProvier = artifacts.require("RentNftAddressProvider");
const RentNft = artifacts.require("RentNft");
const { initSf, K } = require("./_utils");

module.exports = async (_deployer, _network, accounts) => {
  const resolver = await RentNftAddressProvier.deployed();
  await _deployer.deploy(RentNft, resolver.address);

  const sf = await initSf(_network, web3);

  const daiAddress = await sf.resolver.get("tokens.fDAI");
  const dai = await sf.contracts.TestToken.at(daiAddress);
  const daixWrapper = await sf.getERC20Wrapper(dai);
  const daix = await sf.contracts.ISuperToken.at(daixWrapper.wrapperAddress);

  await dai.mint(accounts[0], web3.utils.toWei(K, "ether"), {
    from: accounts[0]
  });
  await dai.approve(daix.address, "1" + "0".repeat(42), { from: accounts[0] }); // :)
  await daix.upgrade(web3.utils.toWei(K, "ether"), { from: accounts[0] });

  const rent = await RentNft.deployed();

  await daix.transfer(rent.address, web3.utils.toWei(K, "ether"), {
    from: accounts[0]
  });
};
