# Introduction

An audit of the **DojoCHIP** ($dojo) reflectionary tax token.

**Date of Audit**: April 17th, 2023

**Report Template**: [Pashov Krum](https://github.com/pashov/audits)

## Disclaimer

Smart contract audits can never verify the complete absence of vulnerabilities, errors, or any other form of issues. This is a time, resource, and expertise bound effort where our team attempts to find and distinguish as many vulnerabilities, errors, and inefficiencies as possible. Security and proper functionality cannot be 100% guaranteed in the event that our review fails to reveal any issues in your smart contracts or you make changes to the smart contracts following review suggestions. Subsequent audits, bug bounty programs, and on-chain monitoring are strongly recommended.

## About Dojo Chip

**Description**: “Dojo Chip is an ERC-20 project that has a community filled with AI fanatics. Their team hopes to provide security to the space through a transaction vetting process. They are looking to build a payment processing system that will allow users to go from credit/debit to crypto without requiring hot wallets such as MetaMask.”

- **Telegram**: https://t.me/dojochipk
- **Twitter**: https://twitter.com/DojoChipERC
- **Website**: https://dojochip.io

**Contract**: [0xc0e24cc5162176fba60108f40d0ffe3bfff73ed6](https://etherscan.io/address/0xc0e24cc5162176fba60108f40d0ffe3bfff73ed6#code)

## Observations

The token contract, `DojoCHIP` is an ERC-20 token with differing buy/sell taxes that route tokens to 3 places: reflections, burns, and a treasury (unverified contract or multi-signature wallet that we assume manages royalties for the team). The token also includes limits such as a max wallet amount, max transaction amount, and block delay. Lastly, the token employs a reflection system that increases the token balances of all holders over time with every buy and sell.

## Verdict

The contract contains numerous informational-level flaws mostly pertaining to gas inefficiencies and lack of documentation. There were also a few larger issues with logic and arithmetic that were not implemented correctly. Some of these larger issues can be mitigated by setting certain fees to zero in order to prevent transactions from touching problematic code. In terms of the "ruggability" of this contract, there does not exist any `onlyOwner` functions that would result in a "rug" or loss of funds. Overall the contract functions moderately well.

## Scope

The following smart contract(s) were in the scope of the audit:

- `DojoCHIP` the $dojo ERC-20 token contract in `dojo.sol`.

The following number of issues were found, organized by severity:
- Critical: 0
- High: 1
- Medium: 2
- Low: 2
- Informational: 10

---

# Findings Summary

| ID     | Title                                                                                         | Severity      |
| ------ | --------------------------------------------------------------------------------------------- | ------------- |
| [H-01] | Inconsistent balances, reflections, and total supply                                          | High          |
| [M-01] | Improper amounts of tokens burned and reflected                                               | Medium        |
| [M-02] | _transfer not checking balance of sender                                                      | Medium        |
| [L-01] | Missing zero address validation                                                               | Low           |
| [L-03] | Integration of a burn function without using ERC20’s native _burn                             | Low           |
| [I-01] | Unnecessary use of internal functions to return public state variables                        | Informational |
| [I-02] | Unnecessary use of internal function that only calls another internal function                | Informational |
| [I-03] | Re-initializing a local variable                                                              | Informational |
| [I-04] | Initializing variables to their default value                                                 | Informational |
| [I-05] | Checking the same condition twice                                                             | Informational |
| [I-06] | Conditional check on variable that cannot be changed                                          | Informational |
| [I-07] | Importing unused interfaces                                                                   | Informational |
| [I-08] | Missing NatSpec                                                                               | Informational |
| [I-09] | Not following Solidity style guide                                                            | Informational |
| [I-10] | Updates to state variable can be overwritten                                                  | Informational |

# Findings

## [H-01] Inconsistent balances, reflections, and total supply
The `DojoCHIP` contract calculates user token balances by multiplying user reflections by the ratio of total reflections to total tokens (aka total supply).

The `_getRate()` function calculates the ratio of reflections to tokens returning the total reflections accrued and total tokens using the following formula:

```math
{\color{Green}\_ getRate()}
=
\frac{{\color{Orange}\_ rTotal}}{{\color{Cyan}\_ tTotal}}
```

The `balanceOf()` function calculates user tokens by multiplying user reflections by the ratio of total tokens to total reflections using the following formula:

```math
{\color{Cyan}balanceOf(} user {\color{Cyan})}
=
\frac{ {\color{Orange}\_ rOwned[} user {\color{Orange}]} }{ \frac{ {\color{Orange}\_ rTotal} }{ {\color{Cyan}\_ tTotal}} }
=
\left( 
    \frac{ {\color{Orange}\_ rOwned[} user {\color{Orange}]} }{1}*
    \frac{ {\color{Cyan}\_ tTotal} }{ {\color{Orange}\_ rTotal} }
\right)
=
\frac{\textcolor{Orange}{\_ rOwned[} user \textcolor{Orange}{]} * {\color{Cyan}\_ tTotal} }{ {\color{Orange}\_ rTotal} }
```

In essence, you solve for user tokens by dividing user reflections by total reflections and multiplying the result by total tokens. Like variables cancel out.

If a buy or sell occurs and reflections are taken, then `_rTotal` is decreased by the reflection fee. When `_rTotal` is decreased, the reflections are distributed to all holders using the previously described formulas. This is able to happen because as `_rTotal` becomes smaller, the number of tokens for all increases since the divisor becomes smaller.

**Example Balance Calculations**

Let's imagine an scenario where ***gucci*** has accrued 1,000 personal reflections, with total reflections at 1,000,000,000 and total tokens at 9,000,000.
1. ${\color{Orange}\textunderscore rOwned[} gucci {\color{Orange}]} = 1,000$
2. ${\color{Orange}\textunderscore rTotal} = 1,000,000,000$
3. ${\color{Cyan}\textunderscore tTotal} = 9,000,000$

Plugging these values into the previously defined formulas brings ***gucci***'s balance to:

```math
{\color{Cyan}balanceOf(} gucci {\color{Cyan})}
=
\frac{{\color{Orange}1,000} * {\color{Cyan}9,000,000}}{{\color{Orange}900,000,000}}
=
\text{\color{Cyan}9 tokens}
```

If `_rTotal` were decreased to 900,000,000 after the deduction of reflection fees then ***gucci***'s balance is adjusted to:

```math
{\color{Cyan}balanceOf(} gucci {\color{Cyan})}
=
\frac{{\color{Orange}1,000} * {\color{Cyan}9,000,000}}{{\color{Orange}900,000,000}}
=
\text{\color{Cyan}10 tokens}
```

As reflection fees are deducted from `_rTotal`, all token balances increase accordingly.

If a decrease in total supply is not accounted for when calculating reflections, then users will end up with more tokens than they should and the sum of all balances will be greater than the true total supply. ​Unfortunately the `_tTotal` variable used in the previous formulas is constant, despite the presence of burning functionality in the contract. This is due to the fact that burned token amounts are deducted from `_tSupply`, not `_tTotal`.  As a result, `_tTotal` does not accurately represent the true total supply which leads to incorrect calculations for transfer amounts, fees, reflections, and overall balances.

If `_tSupply` and `_tTotal` are not kept in sync, the total reflections to total tokens ratio is broken. Any reflections calculated during transactions will be higher since `_rTotal` (total reflections) is always decreasing while `_tTotal` (original total supply) is constant. The `_tSupply` variable is the true total supply of the token since it deducts burned token amounts and the `totalSupply()` function returns its value.

#### Recommendation
There are two options to mend or fix the balance, reflection, and total supply discrepancies:
1. Turn off burn and reflection fees by setting `buyBurnFee`, `buyReflectionFee`, `sellBurnFee`, and `sellReflectionFee` to zero to prevent further losses. Effectively convert the contract to a simple fee token that only takes fees during buys or sells for the treasury since these fees are unaffected by the reflection and burn fees.
**NOTE:** All existing balances and reflection amounts cannot be corrected and could still lead to future issues. Even so, this option is cheaper and easier than completely relaunching the token.

2. Relaunch the token, using `_tSupply` in place of `_tTotal`. Unsure what the ramifications of selling off completely would yield. Depending on the Uniswap accounting all liquidity might not be accessible because the returned total supply is not the actual total supply.

#### Updates
This issue is only dangerous to token logic when `buyReflectionFee`, `sellReflectionFee`, `buyBurnFee`, and `sellBurnFee` are greater than `0`. At the time of writing, the **DojoCHIP** team has followed our first recommendation and set all of these values to `0` in order to stop ongoing balance, reflection, and total supply discrepancies. Although the effects stemming from this issue are lasting and these values can be changed in the future, the discrepancies will not worsen as long as they remain `0`.

## [M-01] Improper amounts of tokens burned and reflected 
On transfers that accrue fees, the total amount of tokens taken for burn and reflection fees is passed to the `burnAndReflect()` function. Inside this function this total is split: half of the tokens are burned and the remaining half of the tokens are subtracted from total reflections.

The `burnAndReflect()` function will always burn half of the sum of `tokensForReflections` and `tokensForBurn` even if `tokensForReflections` is greater than `tokensForBurn` and vice versa. As a result the function’s behavior is:
1. Inconsistent with the actual burn and reflection fees taken
2. Incorrectly adjusts the total tokens reflected and burned

Only `tokensForBurns` worth of tokens should be burned and only `tokensForReflections` worth of tokens should be reflected.

#### Recommendation
Turn off burn and reflection fees by setting `buyBurnFee`, `buyReflectionFee`, `sellBurnFee`, and `sellReflectionFee` to zero to prevent further losses. Effectively convert the contract to a simple fee token that only takes fees during buys or sells for the treasury.

#### Updates
This issue is only dangerous to token logic when `buyReflectionFee`, `sellReflectionFee`, `buyBurnFee`, and `sellBurnFee` are greater than `0`. At the time of writing, the **DojoCHIP** team has followed our recommendation and set all of these values to `0` in order to stop ongoing balance, reflection, and total supply discrepancies. Although the effects stemming from this issue are lasting and these values can be changed in the future, the discrepancies will not worsen as long as they remain `0`.

## [M-02] _transfer not checking balance of sender
Before facilitating any movement of tokens we should first always check to ensure the sender of tokens has a sufficient amount of tokens. Luckily, the contract will go to remove the `amount` of tokens from the sender when it will experience an underflow since the sender’s balance is less than `amount`. This will cause the transaction to revert. However this is highly discouraged.

## [L-01] Missing zero address validation 
The `DojoCHIP` contract contains a `Treasury` address that is used to accumulate royalties. This global variable can be updated via `updateTreasuryWallet`. This method is missing an `address(0)` check.

#### Recommendation
Check that `newTreasuryWallet` is not `address(0)`.

## [L-03] Integration of a burn function without using ERC20’s native _burn
This contract integrates a burn fee which takes a portion of taxes and sends it to the dead address to signify a burn of tokens.
ERC20 includes an internal `_burn` method which not only removes tokens from circulation, it also updates the `totalSupply` accordingly. Performing burns this way is often better than manually transferring tokens to `address(0)` or to `address(0xdead)` because the balances are updated internally and difference in `totalSupply` will be displayed on the block explorer.

## [I-01] Unnecessary use of internal functions to return public state variables
The `DojoCHIP` contract contains an internal function with the sole purpose to return the values of public variables. Originally `_getCurrentSupply()` would return adjusted total supply and reflections by deducting the balances and reflections of any excluded wallets. Since the implementation of this contract eliminated wallet exclusions this function is no longer necessary.

```solidity
function _getCurrentSupply() private view returns(uint256, uint256) {
    uint256 rSupply = _rTotal;
    uint256 tSupply = _tTotal;

    if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
    return (rSupply, tSupply);
}
```
`_getRate()` calls `_getCurrentSupply()` which always returns the values of `_rTotal` and `_tTotal`. However, both are public state variables that are globally accessible. There is no reason to create a function to return values that are accessible anywhere in the contract.

## [I-02] Unnecessary use of internal function that only calls another internal function
The `DojoCHIP` contract features an internal function `_tokenTransfer()` which uses the exact same arguments it was given to call another internal function, `_transferStandard()`.
```solidity
function _tokenTransfer(address sender, address recipient, uint256 amount, uint256 reflectionFee) private {      
    _transferStandard(sender, recipient, amount, reflectionFee);
}
```
#### Recommendation
Instead of calling `_tokenTransfer()` anywhere in the contract, call instead `_transferStandard()`.

## [I-03] Re-initializing a local variable
The `DojoCHIP` contract contains a `swapBack()` function used to sell token royalties allocated for the `Treasury` and send the ETH received for those tokens via `.call` to the `Treasury` address. Inside `swapBack()` it initializes `contractBalance`. Previously in the call stack in the `_transfer()` function, `contractTokenBalance` is initialized to the same value as `contractBalance`.
```solidity
uint256 contractTokenBalance = balanceOf(address(this)); // @audit stores balanceOf(address(this))
// ...
swapBack();
// ...
function swapBack() private {
    uint256 contractBalance = balanceOf(address(this)); // @audit stores balanceOf(address(this)) again
    bool success;
        
    if(contractBalance == 0) {return;}

    swapTokensForEth(contractBalance); 

    tokensForTreasury = 0;

    (success,) = address(Treasury).call{value:address(this).balance}("");
}
```
Before calling `swapBack` in the `_transfer` method, `contractTokenBalance` is set to `balanceOf(address(this)).` Then, inside `swapBack` the first variable initialized is `contractBalance` to the same value; `balanceOf(address(this)).`

#### Recommendation
Pass `contractTokenBalance` to `swapBack` as a parameter.
```solidity
function swapBack(uint256 contractTokenBalance) private {
    // ...
    swapTokensForEth(contractTokenBalance);
}
```

## [I-04] Initializing variables to their default value
The `DojoCHIP` contract contains many instances where a local or global variable is declared and initialized to a default value.
```solidity
Line 817: bool public  tradingActive = false; // All bool variables default to false once declared
Line 1055: uint256 fees = 0; // All uint256 variable default to 0 once declared
Line 1056: uint256 reflectionFee = 0; // All uint256 variables default to 0 once declared
```

## [I-05] Checking the same condition twice
The `DojoCHIP` contract contains a custom `_transfer` function that facilitates the balances of tokens following a sender and receiver type of model. This function has a require statement that ensures the receiver is not `address(0)`. Right after it then checks again that the receiver is not `address(0)`. This is a waste of gas.
```solidity
function _transfer(address from, address to, uint256 amount) internal override {
    require(to != address(0));

    if (limitsInEffect) {
        if (
            // ...
            to != address(0) && // @audit check not necessary
            // ...
        ) {
        // ...
    }
    // ...
}
```
It is not necessary to check if the to address is `address(0)` when the contract would’ve reverted in the original require statement.

## [I-06] Conditional check on variable that cannot be changed
This contract uses a boolean variable called `transferDelayEnabled` which cannot be updated. The variable is hard coded to the value of `true`. This value is checked before performing the block delay logic in the `_transfer` function.
```solidity
if (transferDelayEnabled){
    // ...
}
```
There is no reason to be checking the value of a hardcoded boolean. This wastes gas.

## [I-07] Importing unused interfaces
The `DojoCHIP` contract imports multiple interfaces: `IUniswapV2Router`, `IUniswapV2Factory`, and `IUniswapV2Pair`. The `IUniswapV2Pair` is not used anywhere in the contract. And very limited functions are used from `IUniswapV2Router` and `IUniswapV2Factory` yet the contract imports the entire library of functions.

## [I-08] Missing NatSpec
The `DojoCHIP` contract lacks documentation, primarily in the form of NatSpec comments, for critical state variables and functions. Proper documentation is crucial for helping developers and investors understand the functionality and implementation of your smart contract. To learn more about the NatSpec format and its benefits, please read [here](https://docs.soliditylang.org/en/v0.8.19/natspec-format.html).

## [I-09] Not following Solidity style guide
There are multiple instances throughout the `DojoCHIP` contract where the Solidity style guide is not followed.
- `_tTotal` should be `TOKEN_TOTAL` or `TOTAL_TOKENS` since it is a constant
- `deadAddress` should be `DEAD_ADDRESS` or `DEAD` since it is a constant
- `Treasury` should be `treasury`
- Improper ordering of `internal`, `private`, `public`, and `external` functions
- Improper use of underscore prefixes on functions and variables that are not `private` or `internal`

To learn more about the Solidity style guide, please read [here](https://docs.soliditylang.org/en/v0.8.19/style-guide.html).

## [I-10] Updates to state variable can be overwritten
The `DojoCHIP` contract contains a variable called `swapTokensAtAmount` which acts as a threshold to distribute royalties accumulated by the contract. This value is overwritten by `updateLimits` and hardcoded to `swapTokensAtAmount = _tSupply * 1 / 10000`. `updateLimits` is called every time a call to `_transfer` is made and `refiAmount` is greater than 0.

#### Updates
This issue only affects the token logic when `buyReflectionFee`, `sellReflectionFee`, `buyBurnFee`, and `sellBurnFee` are greater than `0`. At the time of writing, all of these values were set to `0`.