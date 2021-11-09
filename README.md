# DeFiOptions

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/TCGV/DeFiOptions/CI)

Experimental DeFi options trading smart contracts enabling long and short positions for call and put tokenized, collateralized, cash settable european style options.

<p align="center">
<img src="https://github.com/DeFiOptions/DeFiOptions-core/blob/master/diagram.PNG?raw=true" width="500" />
</p>

A dynamic approach was implemented for ensuring collateral for writing options, making use of favorable writer's open option positions for decreasing total required balance provided as collateral.

The exchange accepts stablecoin deposits as collateral for issuing ERC20 option tokens. [Chainlink](https://chain.link/) based price feeds provide the exchange onchain underlying price and volatility updates.

Upon maturity each each [option contract](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/finance/OptionToken.sol) is liquidated and cash settled by the credit provider contract, becoming open for redemption by token holders. In case any option writer happens to be short on funds during settlement the credit provider will register a debt and cover payment obligations, essentially performing a lending operation.

Registered debt will accrue interest until it's repaid by the borrower. Payment occurs either implicitly when any of the borrower's open option positions matures and is cash settled (pending debt will be discounted from profits) or explicitly if the borrower makes a new stablecoin deposit in the exchange.

Exchange's balances not allocated as collateral can be withdrawn by respective owners in the form of stablecoins. If there aren't enough stablecoins available at the moment of the request due to operational reasons the solicitant will receive ERC20 credit tokens issued by the credit provider instead. These credit tokens are a promise of future payment, serving as a proxy for stablecoins since they can be redeemed for stablecoins at a 1:1 value conversion ratio, and are essential for keeping the exchange afloat during episodes of high withdrawal demand.

Holders of credit tokens can request to withdraw (and burn) their balance for stablecoins as long as there are sufficient funds available in the exchange to process the operation, otherwise the withdraw request will be FIFO-queued while the exchange gathers funds, accruing interest until it's finally processed to compensate for the delay.

Test cases defined in [test/finance](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/test/finance) provide more insight into the implementation progress.

## Table of contents

* [Coding Reference](https://github.com/DeFiOptions/DeFiOptions-core#coding-reference)
  * [Making a deposit](https://github.com/DeFiOptions/DeFiOptions-core#making-a-deposit)
  * [Writing options](https://github.com/DeFiOptions/DeFiOptions-core#writing-options)
  * [Collateral allocation](https://github.com/DeFiOptions/DeFiOptions-core#collateral-allocation)
  * [Liquidating positions](https://github.com/DeFiOptions/DeFiOptions-core#liquidating-positions)
  * [Burning options](https://github.com/DeFiOptions/DeFiOptions-core#burning-options)
  * [Underlying feeds](https://github.com/DeFiOptions/DeFiOptions-core#underlying-feeds)
  * [Credit tokens](https://github.com/DeFiOptions/DeFiOptions-core#credit-tokens)
  * [Linear liquidity pool](https://github.com/DeFiOptions/DeFiOptions-core#linear-liquidity-pool)
    * [Pool interface](https://github.com/DeFiOptions/DeFiOptions-core#pool-interface)
    * [Buying from the pool](https://github.com/DeFiOptions/DeFiOptions-core#buying-from-the-pool)
    * [Selling to the pool](https://github.com/DeFiOptions/DeFiOptions-core#selling-to-the-pool)
* [Kovan addresses](https://github.com/DeFiOptions/DeFiOptions-core#kovan-addresses)
* [Get involved](https://github.com/DeFiOptions/DeFiOptions-core#get-involved)
  * [Validate code](https://github.com/DeFiOptions/DeFiOptions-core#validate-code)
  * [Open challenges](https://github.com/DeFiOptions/DeFiOptions-core#open-challenges)
* [Disclaimer](https://github.com/DeFiOptions/DeFiOptions-core#disclaimer)
* [Licensing](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/LICENSE)

## Coding Reference

Below you can find code snippets on how to interact with the options exchange smart contracts for making deposits, calculating collateral, writing options, liquidating positions and everything else you need to know for trading crypto options. If you need further assistance feel free to get in touch.

### Making a deposit

In order to make a deposit first approve a compatible stablecoin allowance for the exchange on the amount you wish to deposit, then call the exchange's `depositTokens` function:

```solidity
ERC20 stablecoin = ERC20(0x123...);
OptionsExchange exchange = OptionsExchange(0xABC...);

address to = 0x456...;
uint value = 100e18;
stablecoin.approve(address(exchange), value);
exchange.depositTokens(to, address(stablecoin), value);
```

*Obs: An [EIP-2612 compatible](https://eips.ethereum.org/EIPS/eip-2612) `depositTokens` function is also provided for deposit functions in a single transaction.*

After the operation completes check total exchange balance for an address using the `balanceOf` function:

```solidity
address owner = 0x456...;
uint balance = exchange.balanceOf(owner);
```

Balance is returned in dollars considering 18 decimal places.

In case you wish to withdraw funds (ex: profits from an operation) call the `withdrawTokens` function:

```solidity
uint value = 50e18;
exchange.withdrawTokens(value);
```

The function will transfer stablecoin tokens to the `msg.sender` for the requested amount, provided that the caller has enough unallocated balance. Since the exchange accepts multiple stablecoins the withdrawer should expect to receive any of these tokens.

*Obs: If there aren't enough stablecoins available in the exchange the solicitant will receive ERC20 credit tokens issued by the credit provider contract which can later be redeemed for stablecoins at a 1:1 value conversion ratio.*

### Writing options

Before writing an option calculate the amount of collateral needed by calling the `calcCollateral` function providing the option parameters:

```solidity
address eth_usd_feed = address(0x987...);
uint volumeBase = 1e18;
uint strikePrice = 1300e18;
uint maturity = now + 30 days;

uint collateral = exchange.calcCollateral(
    eth_usd_feed, 
    10 * volumeBase, 
    OptionsExchange.OptionType.CALL, 
    strikePrice, 
    maturity
);
```

The snippet above calculates the collateral needed for writing ten ETH call options at the strike price of US$ 1300 per ETH maturing in 30 days from the current date.

After checking that the writer has enough unallocated balance to provide as collateral, proceed to write options by calling the `writeOptions` function:

```solidity
address holder = 0xDEF...;

address tkAddr = exchange.writeOptions(
    eth_usd_feed, 
    10 * volumeBase, 
    OptionsExchange.OptionType.CALL, 
    strikePrice, 
    maturity,
    holder
);
```

Options are issued as ERC20 tokens and sent to the specified `holder` address. The `writeOptions` function returns the option token contract address for convenience:

```solidity
ERC20 token = ERC20(tkAddr);
uint balance = token.balanceOf(holder); // equal to written volume

address to = 0x567...;
token.transfer(to, 5 * volumeBase); // considering 'msg.sender == owner'
```

Options are aggregated by their underlying, strike price and maturity, each of which will resolve to a specific ERC20 token contract address. Take advantage of already existent option token contracts when writing options for increased liquidity.

The `calcIntrinsicValue` allows callers to check the updated intrinsict value for an option, specified by its token contract address `tkAddr`:

```solidity
uint iv = exchange.calcIntrinsicValue(tkAddr);
```

Suppose the ETH price has gone up to US$ 1400, and considering that the strike price was set to US$ 1300, then the intrinsic value returned would be `100e18`, i.e., US$ 100. Multiply this value by the held volume to obtain the position's aggregated intrinsic value.

### Collateral allocation

All open positions owned by an address (written or held) are taken into account for allocating collateral regardless of the underlying, option type and maturity, according to the following formula implemented in solidity code:

<p align="center">
<img src="https://latex.codecogs.com/svg.latex?%5Cbegin%7Balign*%7Dcollateral%20%3D%20%5Csum_%7Bi%7D%5E%7B%7D%5Cleft%5Bk_%7Bupper%7D%20%5Ctimes%20%5Csigma%20_%7Bunderlying_%7Bi%7D%7D%20%5Ctimes%20%5Csqrt%7Bdays%5C%20to%5C%20maturity%7D%20%26plus%3B%20%5Cupsilon%5Cleft%20%20%28%20%20option_%7Bi%7D%5E%7B%7D%20%5Cright%20%29%20%5Cright%5D%5Ctimes%20volume_%7Bi%7D%20-%20%5Csum_%7Bj%7D%5E%7B%7D%5Cupsilon%5Cleft%20%28%20option_%7Bj%7D%5E%7B%7D%20%5Cright%20%29%5Ctimes%20volume_%7Bj%7D%5Cend%7Balign*%7D">
</p>

A short position "i" increases required collateral proportionally to the written volume taking into account the period adjusted on-chain historical underlying price volatility and the option intrinsic value ("υ"). A long position "j" decreases required collateral proportionally to the held volume taking into account the option intrinsic value alone. The k<sub>upper</sub> constant plays a role in the liquidation process and serves as an additional security factor protecting against the inherent uncertainty of the underlying price volatility (i.e. the volatility-of-volatility risk).

Call the `calcCollateral` function to perform this calculation and obtain the collateral requirements for a specific address:

```solidity
uint collateral = exchange.calcCollateral(owner);
```

The difference between the address balance and its collateral requirements is the address surplus. The `calcSurplus` function is conveniently provided to perform this calculation:

```solidity
uint surplus = exchange.calcSurplus(owner);
```

The surplus effectively represents the amount of funds available for writing new options and for covering required collateral variations due to underlying price jumps. If it returns zero it means that the specified address is lacking enough collateral and at risk of having its positions liquidated.

### Liquidating positions

Options can be liquidated either individually due to a writer not meeting collateral requirements for covering his open positions, or collectively at the option token contract level upon maturity.

In the first case, when a writer doesn't meet the collateral requirements for covering his open positions, any of his positions will be susceptible to liquidation for reducing liabilities until the writer starts meeting collateral requirements again.

To liquidate a specific writer option in this situation call the `liquidateOptions` function providing both the option token contract address and the writer address:


```solidity
uint value = exchange.liquidateOptions(tkAddr, owner);
```

The function returns the value resulting from liquidating the position (either partially or fully), which is transferred to the respective option token contract and held until maturity, whereupon the contract is fully liquidated and profits are distributed to option holders proportionally to their share of the total supply.

The effective volume liquidated by this function call is calculated using the minimum required volume for the writer to start meeting the collateral requirements again:

<p align="center">
<img src="https://latex.codecogs.com/svg.latex?volume%20%20%3D%20%5Cfrac%7Bcollateral%20-%20balance%7D%7B%5Cleft%20%28k_%7Bupper%7D%20-%20k_%7Blower%7D%20%5Cright%20%29%5Ctimes%20%5Csigma%20_%7Bunderlying%7D%20%5Ctimes%20%5Csqrt%7Bdays%5C%20to%5C%20maturity%7D%7D">
</p>

Here two constants are employed, k<sub>upper</sub> and k<sub>lower</sub>, whose difference enables the clearance of the collateral deficit in a simple manner. Once the liquidation volume is found, the liquidation value is calculated as:

<p align="center">
<img src="https://latex.codecogs.com/svg.latex?value%20%3D%20%5Cleft%20%5B%20k_%7Blower%7D%20%5Ctimes%20%5Csigma%20_%7Bunderlying%7D%20%5Ctimes%20%5Csqrt%7Bdays%20%5C%20to%5C%20maturity%7D%20%2B%20%5Cupsilon%5Cleft%20%28%20option%20%5Cright%20%29%20%5Cright%20%5D%20%5Ctimes%20volume">
</p>

Now in the second case, when the option matures, all option token contract written positions can be liquidated for their intrinsic value. The exchange offers a function overload that accpets an array of options writers addresses for liquidating their positions in a more gas usage efficient way:

```solidity
address[] memory owners = new address[](length);
// initialize array (...)
exchange.liquidateOptions(tkAddr, owners);
```

Liquidated options are cash settled by the credit provider contract and the accumulated capital becomes available for redemption among option holders proportionally to their share of the total token supply:

```solidity
OptionToken optionToken = OptionToken(tkAddr);
optionToken.redeem(holder);
```

In case any option writer happens to be short on funds during settlement the credit provider will register a debt and cover payment obligations, essentially performing a lending operation.

### Burning options

The exchange keeps track of all option writers and holders. Option writers are addresses that create option tokens. Option holders in turn are addresses to whom option tokens are transferred to. On calling the `writeOptions` exchange function an address becomes both writer and holder of the newly issued option tokens, until it decides to transfer them to a third-party.

In order to burn options, for instance to close a position before maturity and release allocated collateral, writers can call the `burn` function from the option token contract:

```solidity
OptionToken token = OptionToken(tokenAddress);
uint amount = 5 * volumeBase;
token.burn(amount);
```

The calling address must be both writer and holder of the specified volume of options that are to be burned, otherwise the function will revert. If the calling address happens to be short biased (written volume > held volume) it will have to purchase option tokens in the market up to the volume it wishes to burn.

### Underlying feeds

Both the `calcCollateral` and the `writeOptions` exchange functions receive the address of the option underlying price feed contract as a parameter. The feed contract implements the following interface:

```solidity
interface UnderlyingFeed {

    function symbol() external view returns (string memory);

    function getLatestPrice() external view returns (uint timestamp, int price);

    function getPrice(uint position) external view returns (uint timestamp, int price);

    function getDailyVolatility(uint timespan) external view returns (uint vol);

    function calcLowerVolatility(uint vol) external view returns (uint lowerVol);

    function calcUpperVolatility(uint vol) external view returns (uint upperVol);
}
```

The exchange depends on these functions to calculate options intrinsic value, collateral requirements and to liquidate positions.

* The `symbol` function is used to create option token contracts identifiers, such as `ETH/USD-EC-13e20-1611964800` which represents an ETH european call option with strike price US$ 1300 and maturity at timestamp `1611964800`.
* The `getLatestPrice` function retrieves the latest quote for the option underlying, for calculating its intrinsic value.
* The `getPrice` function on the other hand retrieves the first price for the underlying registered in the blockchain after a specific timestamp position, and is used to liquidate the option token contract at maturity.
* The `getDailyVolatility` function is used to calculate collateral requirements as described in the [collateral allocation](https://github.com/DeFiOptions/DeFiOptions-core#collateral-allocation) section.
* The `calcLowerVolatility` and `calcUpperVolatility` apply, respectively, the k<sub>lower</sub> and k<sub>upper</sub> constants to the volatility passed as a parameter, also used for calculating collateral requirements, and for liquidating positions as well.

This repository provides a [Chainlink](https://chain.link/) based implementation of the `UnderlyingFeed` interface which allows any Chainlink USD fiat paired currency (ex: ETH, BTC, LINK, EUR) to be used as underlying for issuing options:

* [contracts/feeds/ChainlinkFeed.sol](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/feeds/ChainlinkFeed.sol)

Notice that this implementation provides prefetching functions (`prefetchSample`, `prefetchDailyPrice` and `prefetchDailyVolatility`) which should be called periodically and are used to lock-in underlying prices for liquidation and to optimize gas usage while performing volatility calculations.

### Credit tokens

A [credit token](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/finance/CreditToken.sol) can be viewed as a proxy for any of the exchange's compatible stablecoin tokens, since it can be redeemed for the stablecoin at a 1:1 value conversion ratio. In this sense the credit token is also a stablecoin, one with less liquidity nonetheless.

Credit tokens are issued when there aren't enough stablecoin tokens available in the exchange to cover a withdraw operation. Holders of credit tokens receive interest on their balance (hourly accrued) to compensate for the time they have to wait to finally redeem (burn) these credit tokens for stablecoins once the exchange ensures funds again. To redeem credit tokens call the `requestWithdraw` function, and expect to receive the requested value in any of the exchange's compatible stablecoin tokens:

```solidity
CreditToken ct = CreditToken(0xABC...);
ct.requestWithdraw(value);
```

In case there aren't sufficient stablecoin tokens available to fulfil the request it'll be FIFO-queued for processing when the exchange ensures enough funds.

The exchange will ensure funds for burning credit tokens when debtors repay their debts (for instance when an option token contract is liquidated and the debtor receives profits, which are instantly discounted for pending debts before becoming available to the debtor) or through options settlement processing fees, which by default are not charged, but can be configured upon demand.

### Linear liquidity pool

This project provides a liquidity pool implementation that uses linear interpolation for calculating buy/sell option prices. The diagram below illustrates how the linear interpolation liquidity pool fits in the options exchange trading environment, how market agents interact with it, and provides some context on the pool pricing model:

<p align="center">
<img src="https://github.com/DeFiOptions/DeFiOptions-core/blob/master/linear-liquidity-pool.PNG?raw=true" width="500" />
</p>

The pool holds a pricing parameters data structure for each tradable option which contains a discretized pricing curve calculated off-chain based on a traditional option pricing model (ex: Monte Carlo) that’s “uploaded” to the pool storage. The pool pricing function receives the underlying price (fetched from the underlying price feed) and the current timestamp as inputs, then it interpolates the discrete curve to obtain the desired option’s target price.

A fixed spread is applied on top of the option’s target price for deriving its buy price above the target price, and sell price below the target price. This spread can be freely defined by the pool operator and should be high enough for ensuring the pool is profitable, but not too high as to demotivate traders.

#### Pool interface

The following [liquidity pool interface](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/interfaces/ILiquidityPool.sol) functions are provided for those willing to interact with the options exchange environment:

```solidity
interface ILiquidityPool {

    function depositTokens(address to, address token, uint value) external;

    function listSymbols() external view returns (string memory);

    function queryBuy(string calldata optSymbol) external view returns (uint price, uint volume);

    function querySell(string calldata optSymbol) external view returns (uint price, uint volume);

    function buy(string calldata optSymbol, uint price, uint volume, address token)
        external
        returns (address addr);

    function sell(string calldata optSymbol, uint price, uint volume) external;
}
```

*Obs: [EIP-2612 compatible](https://eips.ethereum.org/EIPS/eip-2612) `buy` and `sell` functions are also provided for trading options in a single transaction.*

Liquidity providers can call the `depositTokens` function for depositing compatible stablecoin tokens into the pool and receive pool tokens in return following a “post-money” valuation strategy, i.e., proportionally to their contribution to the total amount of capital allocated in the pool including the expected value of open option positions. This allows new liquidity providers to enter the pool at any time without harm to pre-existent providers.

Funds are locked in the pool until it reaches the pre-defined liquidation date, whereupon the pool ceases operations and profits are distributed to liquidity providers proportionally to their participation in the total supply of pool tokens.

The `listSymbols` function should be called to obtain the list of tradable options in the pool and returns a string containing all active option symbols, one per line. Symbols are encoded as follows:

- `[underlying symbol]/[base currency]-[type code]-[strike price]-[maturity]`

Where:

- The type code will be “EC” for European Call or “EP” for European Put.

- Strike price is provided in the base currency using a “1e18” decimal base. For instance, considering the USD base currency, 175e19 is equivalent to 1750e18 which in turn converts to 1750 USD.

- Maturity is provided as a Unix timestamp from epoch. For instance, 161784e4 is equivalent to 1617840000 which in turn converts to “GMT: Thursday, 8 April 2021 00:00:00”.

#### Buying from the pool

Traders should first call the `queryBuy` function which receives an option symbol and returns both the spread-adjusted “buy” price and available volume for purchase from the pool, and then call the `buy` function specifying the option symbol, queried “buy” price, desired volume for purchase and the address of the stablecoin used as payment:

```solidity
(uint buyPrice,) = pool.queryBuy(symbol);
uint volume = 1 * volumeBase;
stablecoin.approve(address(pool), price * volume / volumeBase);
pool.buy(symbol, price, volume, address(stablecoin));
```

#### Selling to the pool

Likewise traders should first call the `querySell` function which receives an option symbol and returns both the spread-adjusted “sell” price and available volume the pool is able to purchase, and then call the `sell` function specifying the option symbol, queried “sell” price and the pre-approved option token transfer volume being sold:

```solidity
(uint sellPrice,) = pool.querySell(symbol);
uint volume = 1 * volumeBase;

OptionToken token OptionToken(exchange.resolveToken(symbol));
token.approve(address(pool), price * volume / volumeBase);
pool.sell(symbol, price, volume);
```

Upon a successful transaction payment for the transferred option tokens is provided in the form of balance transferred from the pool account to the `msg.sender` account within the options exchange.

## Kovan addresses

The Options Exchange is available on kovan testnet for validation. Contract addresses are provided in the following table:

| Contract | Address |
| -------- | ------- |
| [OptionsExchange](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/finance/OptionsExchange.sol)         | [0x1233a9d9a02eef1bc24675332684d4bfdd866f8a](https://kovan.etherscan.io/address/0x1233a9d9a02eef1bc24675332684d4bfdd866f8a) |
| [CreditToken](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/finance/CreditToken.sol)                 | [0xae7512c5d996b12830a282eeb9eecb4cf01207d2](https://kovan.etherscan.io/address/0xae7512c5d996b12830a282eeb9eecb4cf01207d2) |
| [Linear Liquidity Pool](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/pools/LinearLiquidityPool.sol) | [0xb0be2a679632f028edb4a3e29bb82ac6ed6d84d9](https://kovan.etherscan.io/address/0xb0be2a679632f028edb4a3e29bb82ac6ed6d84d9) |
| [ETH/USD feed](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/interfaces/UnderlyingFeed.sol)          | [0xF6DF43F27d51289703C2A93289D53C4D5AC79b7d](https://kovan.etherscan.io/address/0xF6DF43F27d51289703C2A93289D53C4D5AC79b7d) |
| [BTC/USD feed](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/contracts/interfaces/UnderlyingFeed.sol)          | [0x261E05174813A0a6dafE208830410768b709E6ca](https://kovan.etherscan.io/address/0x261E05174813A0a6dafE208830410768b709E6ca) |
| [Fakecoin](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/test/common/mock/ERC20Mock.sol)                       | [0xB51E93aA4B4B411A36De9343128299B483DBA133](https://kovan.etherscan.io/address/0xB51E93aA4B4B411A36De9343128299B483DBA133) |

A freely issuable ERC20 fake stablecoin ("fakecoin") is provided for convenience. Simply issue fakecoin tokens for an address you own to be able to interact with the exchange for depositing funds, writing options and evaluate its functionality:

```solidity
ERC20Mock fakecoin = ERC20Mock(0xdd8...);
address to = 0xABC
uint value = 1500e18;
fakecoin.issue(to, value);
```

## Get involved

Did you like this project and wanna get involved? There are a couple of ways in which you can contribute! See below.

Before starting simply [shoot me a message](mailto:defi-options@protonmail.com?subject=DeFiOptions%20%7C%20Interested%20Contributor) describing how do you wish to contribute so we can arrange a plan accordingly.</i>

### Validate code

We aim to provide a reliable, bug-free protocol to the community, however to achieve that a deeper validation of the contracts source code is necessary. You can help by:

* Executing tests against the kovan contract addresses for identifying potential bugs
* Auditing contracts source code files for identifying security issues
* Submitting pull-requests for bug / audit fixes
* Extending the unit tests suite for covering more use cases and edge cases

### Open challenges

There are a few major technical challenges that need to get dealt with for DeFi Options to offer a fully featured user experience:

* ~~Development of a dapp front-end application to make the exchange accessible to non-developers~~
* ~~Design and implementation of a liquidity pool, which will involve knowledge in finance and option pricing models~~
* ~~Allow deposit/withdraw of underlying assets (ex: ETH, BTC) so they can be provided as collateral for writing options against them~~
* ~~Improvement of the incipient governance functionality ([contracts/governance](https://github.com/DeFiOptions/DeFiOptions-core/tree/master/contracts/governance))~~

## Disclaimer

DeFi Options is a proof-of-concept open source software project target for testnets and not intended for use in live environments where financial values are involved. As an open source project our code is provided to the general public under the [GPL-3.0 License](https://github.com/DeFiOptions/DeFiOptions-core/blob/master/LICENSE) without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.

We strongly advise you to seek legal counseling for all relevant jurisdictions before planning to deploy DeFi Options to a live environment to ensure all required regulations are being met. Use it at your own risk.
