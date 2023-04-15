# Introduction

A security audit on the **Dojo Chip** ($dojo) token.

## Disclaimer

A smart contract security review can never verify the complete absence of vulnerabilities. This is a time, resource and expertise bound effort where we try to find as many vulnerabilities, inefficiencies, and implementation flaws as possible. Security cannot be 100% guaranteed after the review or even if the review will find any problems with your smart contracts. Subsequent security reviews, bug bounty programs and on-chain monitoring are strongly recommended.

## About **Dojo Chip**

**Description**: “Dojo Chip is an ERC-20 project that has a community filled with AI fanatics. Their team hopes to provide security to the space through a transaction vetting process. They are looking to build a payment processing system which will allow users to go from credit/debit to Crypto without requiring hot wallets such as MetaMask.”

- **Telegram**: https://t.me/dojochipk
- **Twitter**: https://twitter.com/DojoChipERC
- **Website**: https://dojochip.io

**Contract Address**: [0xc0e24cc5162176fba60108f40d0ffe3bfff73ed6](https://etherscan.io/address/0xc0e24cc5162176fba60108f40d0ffe3bfff73ed6#code)

## Observations

The token contract, `DojoCHIP` is an erc-20 token with differing buy/sell taxes that route to 3 places; reflections, burns, and a treasury (unverified contract which we can only assume to be used for royalty management amongst the team). The token also includes limits such as max wallet amount, max transaction amount, and a block delay. Lastly, the token has a reflectionary system which allows holders to experience an increase in token balance by just holding their tokens over time.

## Verdict

The contract contains numerous informational-level flaws mostly pertaining to gas inefficiencies and no documentation. There were also a few larger issues with logic/arithmetic that were not implemented correctly. Some larger cases could be mitigated by setting certain global variables to 0 to deflect transactions from touching nefarious code. In terms of the ruggability of this contract, there does not exist any dangerous `onlyOwner` methods that will allow the owner to perform any wicked calls. The only function that could cause a major issue if called maliciously by the owner is mentioned at flag **[H-01]**.

## Scope

The following smart contracts were in the scope of the audit:

- `DojoCHIP`, which is the $dojo ERC20 token contract.

The following number of issues were found, categorized by their severity:
- Critical: 1
- High: 1
- Medium: 2
- Low: 3
- Informational: 9

---

# Findings Summary

| ID     | Title                                                                                         | Severity      |
| ------ | --------------------------------------------------------------------------------------------- | ------------- |
| [C-01] | Inconsistent balances, reflections, and total supply                                          | Critical      |
| [H-01] | Owner could set delayDigit to lock future transfers                                           | High          |
| [M-01] | Improper amounts of tokens burned and reflected                                               | Medium        |
| [M-02] | _transfer not checking balance of sender                                                      | Medium        |
| [L-01] | Missing zero address validation                                                               | Low           |
| [L-02] | Updates to global variable overwritten                                                        | Low           |
| [L-03] | Integration of a burn function without using ERC20’s native _burn                             | Low           |
| [I-01] | Unnecessary use of internal functions to return global (public) variables                     | Informational |
| [I-02] | Unnecessary use of internal function that’s sole job is to call another internal function     | Informational |
| [I-03] | Re-initializing a local variable is discouraged                                               | Informational |
| [I-04] | No reason to initialize a variable to a default value.                                        | Informational |
| [I-05] | Double checking same condition is discouraged                                                 | Informational |
| [I-06] | Not following Solidity style-guidelines                                                       | Informational |
| [I-07] | Importing unused Interfaces                                                                   | Informational |
| [I-08] | Missing NatSpec                                                                               | Informational |
| [I-09] | Use of a boolean that can never be changed                                                    | Informational |

# Findings

## [C-01] Inconsistent balances, reflections, and total supply
The `DojoCHIP` contract calculates user token balances by multiplying user reflections by the ratio of total reflections to total tokens (aka total supply).

The `_getRate()` function calculates the ratio of reflections to tokens returning the total reflections accrued and total tokens using the following formula:

```math
    \textcolor{Red}{\_ getRate()}
    =
    \frac{\textcolor{Orange}{\_ rTotal}}{\textcolor{Green}{\_ tTotal}}
```

The `balanceOf()` function calculates user tokens by multiplying user reflections by the ratio of total tokens to total reflections using the following formula:

```math
\textcolor{Lime}{balanceOf(} user \textcolor{Lime}{)}
=
\frac{\textcolor{Orange}{\_ rOwned[}user\textcolor{Orange}{]}}{\frac{\textcolor{Orange}{\_ rTotal}}{\textcolor{Lime}{\_ tTotal}}}
=
\left( 
    \frac{{\color{Orange}\_ rOwned[} user \textcolor{Orange}{]}}{1}*
    \frac{{\textcolor{Lime}\_ tTotal}}{{\color{Orange}\_ rTotal}}
\right)
=
\frac{\textcolor{Orange}{\_ rOwned[} user \textcolor{Orange}{]} * \textcolor{Lime}{\_ tTotal}}{\textcolor{Orange}{\_ rTotal}}
```

In essence, you solve for user tokens by dividing user reflections by total reflections and multiplying the result by total tokens. Like variables cancel out.

If a buy or sell occurs and reflections are taken, then `_rTotal` is decreased by the reflection fee. When `_rTotal` is decreased, the reflections are distributed to all holders using the previously described formulas. This is able to happen because as `_rTotal` becomes smaller, the number of tokens for all increases since the divisor becomes smaller.

**Example Balance Calculations**
Let's imagine an scenario where ***gucci*** has accrued 1,000 personal reflections, with total tokens at 9,000,000 and total reflections at 1,000,000,000.
1. ${\color{Orange}\_ rOwned[} gucci {\color{Orange}]} = 1,000$
2. ${\color{Lime}\_ tTotal} = 9,000,000$
3. ${\color{Orange}\_ rTotal} = 1,000,000,000$

Plugging these values into the previously defined formulas brings ***gucci***'s balance to:

```math
\textcolor{Lime}{balanceOf(} gucci \textcolor{Lime}{)}
=
\frac{\textcolor{Orange}{\textcolor{Orange}{1,000}} * \textcolor{Lime}{9,000,000}}{\textcolor{Orange}{1,000,000,000}}
=
\text{\textcolor{Lime}{9 tokens}}
```

If `_rTotal` were decreased to 900,000,000 after the deduction of reflection fees then ***gucci***'s balance is adjusted to:

```math
\textcolor{Lime}{balanceOf(} gucci \textcolor{Lime}{)}
=
\frac{\textcolor{Orange}{\textcolor{Orange}{1,000}} * \textcolor{Lime}{9,000,000}}{\textcolor{Orange}{900,000,000}}
=
\text{\textcolor{Lime}{10 tokens}}
```

As reflection fees are deducted from `_rTotal`, all token balances increase accordingly.

If a decrease in total supply is not accounted for when calculating reflections, then users will end up with more tokens than they should and the sum of all balances will be greater than the true total supply. ​Unfortunately the `_tTotal` variable used in the previous formulas is constant, despite the presence of burning functionality in the contract. This is due to the fact that burned token amounts are deducted from `_tSupply`, not `_tTotal`.  As a result, `_tTotal` does not accurately represent the true total supply which leads to incorrect calculations for transfer amounts, fees, reflections, and overall balances.

If `_tSupply` and `_tTotal` are not kept in sync, the total reflections to total tokens ratio is broken. Any reflections calculated during transactions will be higher since `_rTotal` (total reflections) is always decreasing while `_tTotal` (original total supply) is constant. The `_tSupply` variable is the true total supply of the token since it deducts burned token amounts and the `totalSupply()` function returns its value.

**Recommendation**
There are two options to mend or fix the balance, reflection, and total supply discrepancies:
1. Turn off burn and reflection fees by setting `buyBurnFee`, `buyReflectionFee`, `sellBurnFee`, and `sellReflectionFee` to zero to prevent further losses. Effectively convert the contract to a simple fee token that only takes fees during buys or sells for the treasury since these fees are unaffected by the reflection and burn fees.
**NOTE:** All existing balances and reflection amounts cannot be corrected and could still lead to future issues. Even so, this option is cheaper and easier than completely relaunching the token.

2. Relaunch the token, using `_tSupply` in place of `_tTotal`. Unsure what the ramifications of selling off completely would yield. Depending on the Uniswap accounting all liquidity might not be accessible because the returned total supply is not the actual total supply.

## [H-01] Owner could set delayDigit to lock future transfers
The `DojoCHIP` contract contains a limit that stops anyone from transacting more than once within a range of blocks set by `delayDigit`. The owner has the ability to set the range of `delayDigit` to be so large that they can lock transactions.

## [M-01] Improper amounts of tokens burned and reflected 
On transfers that accrue fees, the total amount of tokens taken for burn and reflection fees is passed to the `burnAndReflect()` function. Inside this function this total is split: half of the tokens are burned and the remaining half of the tokens are subtracted from total reflections.

The `burnAndReflect()` function will always burn half of the sum of `tokensForReflections` and `tokensForBurn` even if `tokensForReflections` is greater than `tokensForBurn` and vice versa. As a result the function’s behavior is:
1. Inconsistent with the actual burn and reflection fees taken
2. Incorrectly adjusts the total tokens reflected and burned

Only `tokensForBurns` worth of tokens should be burned and only `tokensForReflections` worth of tokens should be reflected.

**Recommendation**
Turn off burn and reflection fees by setting `buyBurnFee`, `buyReflectionFee`, `sellBurnFee`, and `sellReflectionFee` to zero to prevent further losses. Effectively convert the contract to a simple fee token that only takes fees during buys or sells for the treasury.

## [M-02] _transfer not checking balance of sender
Before facilitating any movement of tokens we should first always check to ensure the sender of tokens has a sufficient amount of tokens. Luckily, the contract will go to remove the `amount` of tokens from the sender when it will experience an underflow since the sender’s balance is less than `amount`. This will cause the transaction to revert. However this is highly discouraged.

## [L-01] Missing zero address validation 
The `DojoCHIP` contract contains a `Treasury` address that is used to accumulate royalties. This global variable can be updated via `updateTreasuryWallet`. This method is missing an `address(0)` check.

**Recommendation**
Check the newTreasuryWallet is not `address(0)`.

## [L-02] Updates to global variable overwritten
The `DojoCHIP` contract contains a variable called `swapTokensAtAmount` which acts as a threshold to distribute royalties accumulated by the contract. This value is overwritten by `updateLimits` and hardcoded to `swapTokensAtAmount = _tSupply * 1 / 10000`. `updateLimits` is called every time a call to `_transfer` is made and `refiAmount` is greater than 0.

**Recommendation**
Set `buyBurnFee`, `buyReflectionFee`, `sellBurnFee`, and `sellReflectionFee` to 0 and if `swapTokensAtAmount` needs to be changed, call `updateSwapTokensAtAmount`.

## [L-03] Integration of a burn function without using ERC20’s native _burn
This contract integrates a burn fee which takes a portion of taxes and sends it to the dead address to signify a burn of tokens.
ERC20 includes an internal `_burn` method which not only removes tokens from circulation, it also updates the `totalSupply` accordingly. Performing burns this way is often better than manually transferring tokens to `address(0)` or to `address(0xdead)` because the balances are updated internally and difference in `totalSupply` will be displayed on the block explorer.

## [I-01] Unnecessary use of internal functions to return global (public) variables
The `DojoCHIP` contract contains an internal function with the sole purpose to return the values of globally accessible variables.
```solidity
function _getCurrentSupply() private view returns(uint256, uint256) {
    uint256 rSupply = _rTotal;
    uint256 tSupply = _tTotal;

    if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
    return (rSupply, tSupply);
}
```
`_getCurrentSupply` is called by `_getRate` to return the values of `rSupply` and `tSupply`. Both are public state variables making them globally accessible. In essence, there is no reason to create a function to return values that are accessible anywhere in the contract.

## [I-02] Unnecessary use of internal function that’s sole job is to call another internal function
The `DojoCHIP` contract features an internal function `_tokenTransfer` which takes the same arguments it was given to call another internal function, `_transferStandard`.
```solidity
function _tokenTransfer(address sender, address recipient, uint256 amount, uint256 reflectionFee) private {      
    _transferStandard(sender, recipient, amount, reflectionFee);
}
```
**Recommendation**
Instead of calling `_tokenTransfer` anywhere in the contract, just make a call to `_transferStandard`.

## [I-03] Re-initializing a local variable is discouraged
The `DojoCHIP` contract contains a `swapBack` method used to sell royalties allocated for the `Treasury` and send those tokens via .call to the `Treasury` address. Inside this `swapBack` function it initializes `contractBalance`. Previously in the call stack in the `_transfer` method, `contractTokenBalance` is initialized to the same value as `contractBalance`.
```solidity
uint256 contractTokenBalance = balanceOf(address(this)); // @audit stores balanceOf(address(this))
//
swapBack();
//
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

**Recommendation**
Pass `contractTokenBalance` to `swapBack` as a parameter.
```solidity
function swapBack(uint256 contractTokenBalance) private {
    //
    swapTokensForEth(contractTokenBalance);
}

```

## [I-04] No reason to initialize a variable to a default value
The `DojoCHIP` contract contains many instances where a local or global variable is declared and initialized to a default value.
```solidity
Line 817: bool public  tradingActive = false; // All bool variables default to false once declared
Line 1055: uint256 fees = 0; // All uint256 variable default to 0 once declared
Line 1056: uint256 reflectionFee = 0; // All uint256 variables default to 0 once declared
```

## [I-05] Double checking same condition is discouraged
The `DojoCHIP` contract contains a `_transfer` function that facilitates the balances of tokens following a sender and receiver type of model. This function has a require statement that ensures the receiver is not `address(0)`. Right after it then checks again that the receiver is not `address(0)`. This is a waste of gas.
```solidity
function _transfer(address from, address to, uint256 amount) internal override {
    require(to != address(0));

    if (limitsInEffect) {
        if (
            //
            to != address(0) && // @audit check not necessary
            //
        ) {
        //
    }
    //
}
```
It is not necessary to check if the to address is `address(0)` when the contract would’ve reverted in the original require statement.

## [I-06] Not following Solidity style-guidelines
There are multiple occasions in the `DojoCHIP` contract where Solidity style guidelines are not followed.
- `_tTotal` should be `TOKEN_TOTAL` or `TOTAL_TOKENS` since it is a constant
- `deadAddress` should be `DEAD_ADDRESS` or `DEAD` since it is a constant
- `Treasury` should be `treasury`
- Over-use of _underscoreWord styling. Only use _ when a function is internal or variable is private.

## [I-07] Importing unused Interfaces
The `DojoCHIP` contract imports multiple interfaces: `IUniswapV2Router`, `IUniswapV2Factory`, and `IUniswapV2Pair`. The `IUniswapV2Pair` is not used anywhere in the contract. And very limited functions are used from `IUniswapV2Router` and `IUniswapV2Factory` yet the contract imports the entire library of functions.

## [I-08] Missing NatSpec
The `DojoCHIP` contract is missing any type of documentation, primarily NatSpec. Proper documentation is extremely important in being able to seamlessly communicate implementation with developers, auditors, or investors. Check out more about NatSpec [here](https://docs.soliditylang.org/en/v0.8.17/natspec-format.html).

## [I-09] Use of a boolean that can never be changed
This contract uses a boolean variable called `transferDelayEnabled` which cannot be updated. The variable is hard coded to the value of `true`. This value is checked before performing the block delay logic in the `_transfer` function.
```solidity
if (transferDelayEnabled){
    //
}
```
There is no reason to be checking the value of a hardcoded boolean. This wastes gas.