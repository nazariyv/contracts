const SuperfluidSDK = require("@superfluid-finance/ethereum-contracts");

const getNetwork = (network) => {
  switch (network) {
    case "live":
      return 1;
    case "goerli":
      return 5;
    default:
      throw new Error(`unknown network -> [${network}]`);
  }
};

const K = "1000";

const initSf = async (network, web3) => {
  const version = "0.1.2-preview-20201014";
  const sf = new SuperfluidSDK.Framework({
    chainId: getNetwork(network),
    version: version,
    web3Provider: web3.currentProvider
  });
  await sf.initialize();
  return sf;
};

module.exports = {
  getNetwork,
  K,
  initSf
};
