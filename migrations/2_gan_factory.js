const GanFaceFactory = artifacts.require("GanFaceFactory");

module.exports = (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    _deployer.deploy(GanFaceFactory);
  }
};
