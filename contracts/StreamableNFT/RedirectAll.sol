// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import {
  ISuperfluid,
  ISuperToken,
  ISuperAgreement,
  ISuperApp,
  SuperAppBase,
  SuperAppDefinitions
} from "./SuperAppBase.sol";
import {
  IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

// redirects all the streams on owner change
contract RedirectAll is SuperAppBase {
  ISuperfluid private host;
  IConstantFlowAgreementV1 private cfa;
  ISuperToken private superToken;
  address public receiver;

  event ReceiverChanged(address receiver);

  constructor(
    ISuperfluid _host,
    IConstantFlowAgreementV1 _cfa,
    ISuperToken _superToken,
    address _receiver
  ) {
    require(address(_host) != address(0), "host is nil");
    require(address(_cfa) != address(0), "cfa is nil");
    require(address(_superToken) != address(0), "accepted token is nil");
    // TODO: this aborts the deployment, but should be in. Include later
    // require(!_host.isApp(ISuperApp(receiver)), "receiver is a super app");

    host = _host;
    cfa = _cfa;
    superToken = _superToken;
    receiver = _receiver;

    uint256 configWord =
      SuperAppDefinitions.TYPE_APP_FINAL |
        SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
        SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
        SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

    host.registerApp(configWord);
  }

  function currentReceiver()
    external
    view
    returns (
      uint256,
      address,
      int96
    )
  {
    (uint256 startTime, int96 flowRate, , ) =
      cfa.getFlow(superToken, address(this), receiver);
    return (startTime, receiver, flowRate);
  }

  function _updateOutflow(bytes calldata _ctx) private returns (bytes memory) {
    int96 netFlowRate = cfa.getNetFlow(superToken, address(this));
    (, int96 outFlowRate, , ) =
      cfa.getFlow(superToken, address(this), receiver);
    // TODO: potential underflow / overflow. 0.8.0 built in safety mechanism. use SafeMath
    // or reverts
    int96 inFlowRate = netFlowRate + outFlowRate;

    // we update the existing flow here. This in turn will re-direct to the receiver
    if (outFlowRate != int96(0)) {
      (bytes memory newCtx, ) =
        host.callAgreementWithContext(
          cfa,
          abi.encodeWithSelector(
            cfa.updateFlow.selector,
            superToken,
            receiver,
            inFlowRate,
            new bytes(0)
          ),
          _ctx
        );
      return newCtx;
    } else if (inFlowRate == int96(0)) {
      (bytes memory newCtx, ) =
        host.callAgreementWithContext(
          cfa,
          abi.encodeWithSelector(
            cfa.deleteFlow.selector,
            superToken,
            address(this),
            receiver,
            new bytes(0)
          ),
          _ctx
        );
      return newCtx;
    } else {
      (bytes memory newCtx, ) =
        host.callAgreementWithContext(
          cfa,
          abi.encodeWithSelector(
            cfa.createFlow.selector,
            superToken,
            receiver,
            inFlowRate,
            new bytes(0)
          ),
          _ctx
        );
      return newCtx;
    }
  }

  function _changeReceiver(address newReceiver) internal {
    require(newReceiver != address(0), "New receiver is zero address");
    // @dev because our app is registered as final, we can't take downstream apps
    // ! TODO:
    // require(!_host.isApp(ISuperApp(newReceiver)), "New receiver can not be a superApp");
    if (newReceiver == receiver) return;
    host.callAgreement(
      cfa,
      abi.encodeWithSelector(
        cfa.deleteFlow.selector,
        superToken,
        address(this),
        receiver,
        new bytes(0)
      )
    );
    host.callAgreement(
      cfa,
      abi.encodeWithSelector(
        cfa.createFlow.selector,
        superToken,
        newReceiver,
        cfa.getNetFlow(superToken, address(this)),
        new bytes(0)
      )
    );

    receiver = newReceiver;
    emit ReceiverChanged(receiver);
  }

  /**************************************************************************
   * SuperApp callbacks
   *************************************************************************/

  function afterAgreementCreated(
    ISuperToken _superToken,
    bytes calldata _ctx,
    address _agreementClass,
    bytes32, /*agreementId*/
    bytes calldata /*cbdata*/
  )
    external
    override
    onlyExpected(_superToken, _agreementClass)
    onlyHost
    returns (bytes memory)
  {
    return _updateOutflow(_ctx);
  }

  function afterAgreementUpdated(
    ISuperToken _superToken,
    bytes calldata _ctx,
    address _agreementClass,
    bytes32, /*agreementId*/
    bytes calldata /*cbdata*/
  )
    external
    override
    onlyExpected(_superToken, _agreementClass)
    onlyHost
    returns (bytes memory)
  {
    return _updateOutflow(_ctx);
  }

  function afterAgreementTerminated(
    ISuperToken _superToken,
    bytes calldata _ctx,
    address _agreementClass,
    bytes32, /* agreementId */
    bytes calldata /*cbdata*/
  ) external override onlyHost returns (bytes memory) {
    // According to the app basic law, we should never revert in a termination callback
    if (!_isSameToken(superToken) || !_isCFAv1(_agreementClass)) return _ctx;
    return _updateOutflow(_ctx);
  }

  function _isSameToken(ISuperToken _superToken) private view returns (bool) {
    return address(_superToken) == address(superToken);
  }

  function _isCFAv1(address _agreementClass) private pure returns (bool) {
    return
      ISuperAgreement(_agreementClass).agreementType() ==
      keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
  }

  modifier onlyHost() {
    require(msg.sender == address(host), "RedirectAll: support only one host");
    _;
  }

  modifier onlyExpected(ISuperToken _superToken, address _agreementClass) {
    require(_isSameToken(_superToken), "RedirectAll: not accepted token");
    require(_isCFAv1(_agreementClass), "RedirectAll: only CFAv1 supported");
    _;
  }
}
