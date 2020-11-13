const RentNftAddressProvider = artifacts.require("RentNftAddressProvider");
const { initSf, getNetwork } = require("./_utils");

module.exports = async (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    await _deployer.deploy(RentNftAddressProvider, getNetwork(_network));
    const resolver = await RentNftAddressProvider.deployed();

    // TODO. make this deployment context global to persistent in the next script
    // and avoid re-initializing
    const sf = await initSf(_network, web3);

    const daiAddress = await sf.resolver.get("tokens.fDAI");
    const dai = await sf.contracts.TestToken.at(daiAddress);
    const daixWrapper = await sf.getERC20Wrapper(dai);
    const daix = await sf.contracts.ISuperToken.at(daixWrapper.wrapperAddress);

    resolver.setToken(
      web3.eth.abi.encodeParameter("bytes", web3.utils.stringToHex("DAI")),
      daix.address
    );
  }
};
