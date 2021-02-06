# DeFiOptions

Experimental DeFi options trading smart contracts enabling long and short positions for call and put european style options.

<p align="center">
<img src="https://github.com/TCGV/DeFiOptions/blob/master/diagram.PNG?raw=true" width="500" />
</p>

A dynamic approach was implemented for ensuring collateral for writing options, making use of favorable writer's open option positions for decreasing total required balance provided as collateral.

The exchange accepts stablecoin deposits as collateral for issuing ERC20 option tokens. [Chainlink](https://chain.link/) based price feeds provide the exchange onchain underlying price and volatility updates.

Upon maturity each option contract is liquidated, cash settled by the credit provider contract and destroyed (through `selfdestruct`). In case any option writer happens to be short on funds during settlement the credit provider will register a debt and cover payment obligations, essentially performing a lending operation.

Registered debt will accrue interest until it's repaid by the borrower. Payment occurs either automatically when any of the borrower's open option positions matures and is cash settled (pending debt will be discounted from profits) or manually if the borrower makes a new stablecoin deposit.

Exchange's balances not allocated as collateral can be withdrawn by respective owners in the form of stablecoins. If there aren't enough stablecoins available the solicitant will receive ERC20 credit tokens issued by the credit provider.

Holders of credit tokens can request to withdraw (and burn) their balance for stablecoins as long as there are sufficient funds available in the exchange to process the operation, otherwise the withdraw request will be FIFO-queued while the exchange gathers funds, accruing interest until it's finally processed to compensate for the delay.

Test cases defined in [test/finance](https://github.com/TCGV/DeFiOptions/blob/master/test/finance) provide more insight into the implementation progress.

## Table of contents

* [Coding Reference](https://github.com/TCGV/DeFiOptions#coding-Reference)
  * [Making a deposit](https://github.com/TCGV/DeFiOptions#making-a-deposit)
  * [Writing options](https://github.com/TCGV/DeFiOptions#writing-options)
  * [Collateral allocation](https://github.com/TCGV/DeFiOptions#collateral-allocation)
  * [Liquidating positions](https://github.com/TCGV/DeFiOptions#liquidating-positions)
  * [Burning options](https://github.com/TCGV/DeFiOptions#burning-options)
  * [Underlying feeds](https://github.com/TCGV/DeFiOptions#underlying-feeds)
  * [Credit tokens](https://github.com/TCGV/DeFiOptions#credit-tokens)
* [Kovan addresses](https://github.com/TCGV/DeFiOptions#kovan-addresses)
* [Get involved](https://github.com/TCGV/DeFiOptions#get-involved)
  * [Validate code](https://github.com/TCGV/DeFiOptions#validate-code)
  * [Open challenges](https://github.com/TCGV/DeFiOptions#open-challenges)
  * [Support mainnet](https://github.com/TCGV/DeFiOptions#support-mainnet)
* [Licensing](https://github.com/TCGV/DeFiOptions/blob/master/LICENSE)

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

After the operation completes check total exchange balance for an address using the `balanceOf` function:

```solidity
address owner = 0x456...;
uint balance = exchange.balanceOf(owner);
```

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
uint volumeBase = 1e9;
uint strikePrice = 1300e8;
uint maturity = now + 30 days;

uint collateral = exchange.calcCollateral(
    eth_usd_feed, 
    10.mul(volumeBase), 
    OptionsExchange.OptionType.CALL, 
    strikePrice, 
    maturity
);
```

The snippet above calculates the collateral needed for writing ten ETH call options at the strike price of US$ 1300 per ETH maturing in 30 days from the current date.

After checking that the writer has enough unallocated balance to provide as collateral, proceed to write options by calling the `writeOptions` function:

```solidity
uint id = exchange.writeOptions(
    eth_usd_feed, 
    10.mul(volumeBase), 
    OptionsExchange.OptionType.CALL, 
    strikePrice, 
    maturity
);
```

Options are issued as ERC20 tokens, and the `writeOptions` function returns an `id` for the operation which can be used to resolve the respective token contract address:

```solidity
address tokenAddress = exchange.resolveToken(id);
ERC20 token = ERC20(tokenAddress);
uint balance = token.balanceOf(owner); // equal to written volume

address to = 0xDEF...;
token.transfer(to, 5.mul(volumeBase)); // considering 'msg.sender == owner'
```

Options are aggregated by their underlying, strike price and maturity, each of which will resolve to a specific ERC20 token contract address. Take advantage of already existent option token contracts when writing options for increased liquidity.

The `calcIntrinsicValue` allows callers to check the updated intrinsict value for an option, resolved by an operation `id`:

```solidity
uint iv = exchange.calcIntrinsicValue(id);
```

Suppose the ETH price has gone up to US$ 1400, and considering that the strike price was set to US$ 1300, then the intrinsic value returned would be `100e8`, i.e., US$ 100. Multiply this value by the held volume to obtain the position's aggregated intrinsic value.

### Collateral allocation

All open positions owned by an address (written or held) are taken into account for allocating collateral regardless of the underlying, option type and maturity, according to the following formula implemented in solidity code:

<p align="center">
<img src="https://latex.codecogs.com/svg.latex?%5Cbegin%7Balign*%7Dcollateral%20%3D%20%5Csum_%7Bi%7D%5E%7B%7D%5Cleft%5Bk_%7Bupper%7D%20%5Ctimes%20%5Csigma%20_%7Bunderlying_%7Bi%7D%7D%20%5Ctimes%20%5Csqrt%7Bdays%5C%20to%5C%20maturity%7D%20%26plus%3B%20%5Cupsilon%5Cleft%20%28%20%20option_%7Bi%7D%5E%7B%7D%20%5Cright%20%29%20%5Cright%5D%5Ctimes%20volume_%7Bi%7D%20-%20%5Csum_%7Bj%7D%5E%7B%7D%5Cupsilon%5Cleft%20%28%20option_%7Bj%7D%5E%7B%7D%20%5Cright%20%29%5Ctimes%20volume_%7Bj%7D%5Cend%7Balign*%7D">
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

To liquidate a specific writer option in this situation call the `liquidateOptions` function providing the original operation `id`:


```solidity
uint value = exchange.liquidateOptions(id);
```

The function returns the value resulting from liquidating the position (either partially or fully), which is transferred to the respective option token contract and held until maturity, whereupon the contract is fully liquidated and profits are distributed to option holders proportionally to their share of the total supply.

The effective volume liquidated by this function call is calculated using the minimum required volume for the writer to start meeting the collateral requirements again:

<p align="center">
<img src="https://latex.codecogs.com/svg.latex?volume%20%20%3D%20%5Cfrac%7Bcollateral%20-%20balance%7D%7B%5Cleft%20%28k_%7Bupper%7D%20-%20k_%7Blower%7D%20%5Cright%20%29%5Ctimes%20%5Csigma%20_%7Bunderlying%7D%20%5Ctimes%20%5Csqrt%7Bdays%5C%20to%5C%20maturity%7D%20&plus;%20%5Cupsilon%5Cleft%20%28%20option%20%5Cright%20%29%7D">
</p>

Here two constants are employed, k<sub>upper</sub> and k<sub>lower</sub>, whose difference enables the clearance of the collateral deficit in a simple manner. Once the liquidation volume is found, the liquidation value is calculated as:

<p align="center">
<img src="https://latex.codecogs.com/svg.latex?value%20%3D%20k_%7Blower%7D%20%5Ctimes%20%5Csigma%20_%7Bunderlying%7D%20%5Ctimes%20%5Csqrt%7Bdays%5C%20to%5C%20maturity%7D%5Ctimes%20volume">
</p>

Now in the second case, when the option matures, the option token contract is liquidated through its `destroy` function:

```solidity
OptionToken token = OptionToken(tokenAddress);
token.destroy();
```

By calling this function all still active written options from the token contract are liquidated, cash settled by the credit provider contract and profits are distributed among option holders proportionally to their share of the total supply. Then the token contract is destroyed (through `selfdestruct`). In case any option writer happens to be short on funds during settlement the credit provider will register a debt and cover payment obligations, essentially performing a lending operation.

### Burning options

The exchange keeps track of all option writers and holders. Option writers are addresses that create option tokens. Option holders in turn are addresses to whom option tokens are transferred to. On calling the `writeOptions` exchange function an address becomes both writer and holder of the newly issued option tokens, until it decides to transfer them to a third-party.

In order to burn options, for instance to close a position before maturity and release allocated collateral, writers can call the `burn` function from the option token contract:

```solidity
OptionToken token = OptionToken(tokenAddress);
uint amount = 5.mul(volumeBase);
token.burn(amount);
```

The calling address must be both writer and holder of the specified volume of options that are to be burned, otherwise the function will revert. If the calling address happens to be short biased (written volume > held volume) it will have to purchase option tokens in the market up to the volume it wishes to burn.

### Underlying feeds

Both the `calcCollateral` and the `writeOptions` exchange functions receive the address of the option underlying price feed contract as a parameter. The feed contract implements the following interface:

```solidity
interface UnderlyingFeed {

    function getCode() external view returns (string memory);

    function getLatestPrice() external view returns (uint timestamp, int price);

    function getPrice(uint position) external view returns (uint timestamp, int price);

    function getDailyVolatility(uint timespan) external view returns (uint vol);

    function calcLowerVolatility(uint vol) external view returns (uint lowerVol);

    function calcUpperVolatility(uint vol) external view returns (uint upperVol);
}
```

The exchange depends on these functions to calculate options intrinsic value, collateral requirements and to liquidate positions.

* The `getCode` function is used to create option token contracts identifiers, such as `ETH/USD-EC-13e10-1611964800` which represents an ETH european call option with strike price US$ 1300 and maturity at timestamp `1611964800`.
* The `getLatestPrice` function retrieves the latest quote for the option underlying, for calculating its intrinsic value.
* The `getPrice` function on the other hand retrieves the first price for the underlying registered in the blockchain after a specific timestamp position, and is used to liquidate the option token contract at maturity.
* The `getDailyVolatility` function is used to calculate collateral requirements as described in the [collateral allocation](https://github.com/TCGV/DeFiOptions#collateral-allocation) section.
* The `calcLowerVolatility` and `calcUpperVolatility` apply, respectively, the k<sub>lower</sub> and k<sub>upper</sub> constants to the volatility passed as a parameter, also used for calculating collateral requirements, and for liquidating positions as well.

This repository provides a [Chainlink](https://chain.link/) based implementation of the `UnderlyingFeed` interface which allows any Chainlink USD fiat paired currency (ex: ETH, BTC, LINK, EUR) to be used as underlying for issuing options:

* [contracts/feeds/ChainlinkFeed.sol](https://github.com/TCGV/DeFiOptions/blob/master/contracts/feeds/ChainlinkFeed.sol)

Notice that this implementation provides prefetching functions (`prefetchSample`, `prefetchDailyPrice` and `prefetchDailyVolatility`) which should be called periodically and are used to lock-in underlying prices for liquidation and to optimize gas usage while performing volatility calculations.

### Credit tokens

A [credit token](https://github.com/TCGV/DeFiOptions/blob/master/contracts/finance/CreditToken.sol) can be viewed as a proxy for any of the exchange's compatible stablecoin tokens, since it can be redeemed for the stablecoin at a 1:1 value conversion ratio. In this sense the credit token is also a stablecoin, one with less liquidity nonetheless.

Credit tokens are issued when there aren't enough stablecoin tokens available in the exchange to cover a withdraw operation. Holders of credit tokens receive interest on their balance (hourly accrued) to compensate for the time they have to wait to finally redeem (burn) these credit tokens for stablecoins once the exchange ensures funds again. To redeem credit tokens call the `requestWithdraw` function, and expect to receive the requested value in any of the exchange's compatible stablecoin tokens:

```solidity
CreditToken ct = CreditToken(0xABC...);
ct.requestWithdraw(value);
```

In case there aren't sufficient stablecoin tokens available to fulfil the request it'll be FIFO-queued for processing when the exchange ensures enough funds.

The exchange will ensure funds for burning credit tokens when debtors repay their debts (for instance when an option token contract is liquidated and the debtor receives profits, which are instantly discounted for pending debts before becoming available to the debtor) or through options settlement processing fees, which by default are not charged, but can be configured upon demand.

## Kovan addresses

The Options Exchange is available on kovan testnet for validation. Contract addresses are provided in the following table:

| Contract | Address |
| -------- | ------- |
| [OptionsExchange](https://github.com/TCGV/DeFiOptions/blob/master/contracts/finance/OptionsExchange.sol) | [0x15708beacc98a32b40227a8385c9f3c5abffa422](https://kovan.etherscan.io/address/0x15708beacc98a32b40227a8385c9f3c5abffa422) |
| [CreditToken](https://github.com/TCGV/DeFiOptions/blob/master/contracts/finance/CreditToken.sol)         | [0xee53535e2fafc4f8e435d4071cf1422460a938f9](https://kovan.etherscan.io/address/0xee53535e2fafc4f8e435d4071cf1422460a938f9) |
| [ETH/USD feed](https://github.com/TCGV/DeFiOptions/blob/master/contracts/interfaces/UnderlyingFeed.sol)  | [0xA7fb51007A7ba3F4cC9B5500722C55A007BBBaB4](https://kovan.etherscan.io/address/0xA7fb51007A7ba3F4cC9B5500722C55A007BBBaB4) |
| [BTC/USD feed](https://github.com/TCGV/DeFiOptions/blob/master/contracts/interfaces/UnderlyingFeed.sol)  | [0x9f9C4f51fDe9caA9A07638C67551035b7a7E37F1](https://kovan.etherscan.io/address/0x9f9C4f51fDe9caA9A07638C67551035b7a7E37F1) |
| [ERC20Mock](https://github.com/TCGV/DeFiOptions/blob/master/test/common/mock/ERC20Mock.sol)              | [0xdd831B3a8D411129e423C9457a110f984e0f2A61](https://kovan.etherscan.io/address/0xdd831B3a8D411129e423C9457a110f984e0f2A61) |

A freely issuable ERC20 fake stablecoin ("fakecoin") is provided for convenience. Simply issue fakecoin tokens for an address you own to be able to interact with the exchange for depositing funds, writing options and evaluate its functionality:

```solidity
ERC20Mock fakecoin = ERC20Mock(0xdd8...);
address to = 0xABC
uint value = 1500e8;
fakecoin.issue(to, value);
```

## Get involved

Did you like this project and wanna get involved? There are three ways in which you can contribute! See below.

### Validate code

The main goal of this project is to deploy Options Exchange to mainnet, however before doing that a deeper validation of the contracts source code is necessary. You can help by:

* Executing tests against the kovan contract addresses for identifying potential bugs
* Auditing contracts source code files for identifying security issues
* Submitting pull-requests for bug / audit fixes
* Extending the unit tests suite for covering more use cases and edge cases

### Open challenges

There are a few major technical challenges that will need to get dealt with if the project gains traction and is deployed to mainnet:

* Development of a front-end application
* Introduction of liquidity pools
* Improvement of governance functionality

### Support mainnet

If you want to see this project on mainnet you can contribute with an ETH donation to the following address:

* [0xb48E85248d3FD32bBa0ad94916F64674Ab151B3E](https://etherscan.io/address/0xb48E85248d3FD32bBa0ad94916F64674Ab151B3E)

The goal is to collect `10 ETH`. Donations will be strictly used to support deployment and operational costs. Operational costs include execution of daily calls to deployed contracts functions that help keep the exchange afloat, such as calls to underlying price feeds "pre-fetch" functions and to option token contracts "destroy" function.

As an incentive, upon deployment to mainnet credit tokens will be issued to all addresses from which donations are received considering the highest ETH price recorded since the donation up to the deployment date plus a 100% gratitude reward.

If the project doesn't reach its validation and donation goals all collected ETH will be returned to original senders, discounted only by the transaction processing fee.
