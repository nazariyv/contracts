const RentNftAddressProvider = artifacts.require("RentNftAddressProvider");
const { initSf } = require("./_utils");

module.exports = async (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    const networkId = _network === "goerli" ? "5" : "0";
    await _deployer.deploy(RentNftAddressProvider, networkId);
    const resolver = await RentNftAddressProvider.deployed();

    // TODO. make this deployment context global to persistent in the next script
    // and avoid re-initializing
    const sf = await initSf();

    const daiAddress = await sf.resolver.get("tokens.fDAI");
    const dai = await sf.contracts.TestToken.at(daiAddress);
    const daixWrapper = await sf.getERC20Wrapper(dai);
    const daix = await sf.contracts.ISuperToken.at(daixWrapper.wrapperAddress);

    resolver.setToken("DAI", daix.address);
  }
};
