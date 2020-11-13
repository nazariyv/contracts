// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./TradeableCashflow.sol";

contract CashflowFactory {
  // TODO: to be hooked up to graph
  // TODO: flow could be negative? (int96 in superfluid)
  // event NewCashflow(address owner, address token);

  // owner address -> tradeable cashflow address (using only a single token id: 1)
  // this implies no resending of these cashflows. one-to-one mapping
  // mapping(address => address) public registry;

  // constructor() {}

  // ! rationale for this contract is to then integrate it with the graph
  // graph would keep the record of all the cashflows created from here

  function newCashflow(
    address _owner,
    ISuperfluid _host,
    IConstantFlowAgreementV1 _cfa,
    ISuperToken _token
  ) public returns (address) {
    // this gets created on new lend, todo: need to ensure that _owner is the current owner of the NFT

    TradeableCashflow tcf =
      new TradeableCashflow(
        _owner,
        "FranTradeableCashflow",
        "TCF",
        _host,
        _cfa,
        _token
      );
    // registry[_owner] = address(tcf);
    return address(tcf);
  }
}
