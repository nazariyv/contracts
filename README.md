# Welcome to RENFT - Rent NFT

## Flow / Vision

When you generate a face, this will deploy a GanFaceNft ERC721 & TradeableCashflow ERC721 contracts

The former is the utility token, whereas the latter is the tokenized representation of the former's outstanding borrowing streamed payments. i.e. to borrow the GanFaceNft, you must pay the money for the service, this money is streamed into the TradeableCashflow contract (determined from GanFaceNft), which in turn redirects the stream to the owner of the GanFaceNft NFT. If the owner sends the latter to someone else, they will now receive any streamed money. Thus, we have decoupled the utility token from its cashflows.

TradeableCashflow is valid only for the period of the rent. Owner of the GanFaceNft is free to trade the cashflow on DEXes, or keep it. As soon as this contract changes hands, all the flows get re-directed to the new owner.

GanFaceNft gets deployed on face mint. TradeableCashflow gets deployed on lend and starts receiving money on borrow start. It stops receiving money on return and redirects the money to the new owner when one changes.

GanFaceNft gets deployed through a factory contract. This way we can keep track of all of the deployed contracts and can point the graph to a single contract to index all this info for us

There is a faucet for fDAIx in RentNFT. Find the Rent NFT menu bar, and you will see the faucet tab towards the end

Lending an NFT implies creation of TradeableCashflow where the receiver is the current owner of the NFT. The stream is only active for the duration of the borrow and it is responsibility of the borrower to stop the stream in time, this will also serve them as a good reminder to return the NFT. Otherwise, they run the risk of losing the collateral + cotinue paying the stream.

Borrowing an NFT implies transferring the NFT to the borrower, collecting the collateral and setting up a stream to TradeableCashflow. This stream theoretically can be active indefinitely, so it is in the interest of the borrower to return the NFT and stop the stream. If the NFT is not returned, the stream is not stopped. This will wade out malicious activity.

Happy Face Renting!

## Limitations - This is an MVP

1. Nothing stops the borrower from simply stopping the stream right now. This can be solved by automatically claiming the lender's collateral for them.
2. Borrower can default. Once again, claim their collateral.
3. Unless the borrower closes the stream, it will continue. This can be mitigated with kron jobs or OpenzeppelinDefender (testnets).
4. Tests are outdated.
5. This is an MVP. One cashflow per NFT holder.
6. NFT contracts re-deployed (instead of incrementing tokenID) - expensive.
7. I have to deploy tradeable cashflow contract from the client, since factory is hitting gas limit
