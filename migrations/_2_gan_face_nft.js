// const GanFaceNft = artifacts.require("GanFaceNft");
// const SuperfluidSDK = require("@superfluid-finance/ethereum-contracts");

// module.exports = function (_deployer, _network) {
//   if (_network === "development" || _network === "goerli") {
//     const version = "0.1.2-preview-20201014";
//     const sf = new SuperfluidSDK.Framework({
//       chainId: getNetwork(network),
//       version: version,
//       web3Provider: web3.currentProvider
//     });
//     await sf.initialize();

//     const owner = "0x9D3a930E48740501c94978Df634cbB40a1874D26";
//     const daiAddress = await sf.resolver.get("tokens.fDAI");
//     const dai = await sf.contracts.TestToken.at(daiAddress);
//     const daixWrapper = await sf.getERC20Wrapper(dai);
//     const daix = await sf.contracts.ISuperToken.at(daixWrapper.wrapperAddress);

//     // Use deployer to state migration tasks.
//     _deployer.deploy(GanFaceNft, owner, sf.host.address, sf.agreements.cfa.address, daix.address);
//   }
// };
