# Introduction

A security audit on the **Dojo Chip** ($dojo) token.

## Disclaimer

A smart contract security review can never verify the complete absence of vulnerabilities. This is a time, resource and expertise bound effort where we try to find as many vulnerabilities, inefficiencies, and implementation flaws as possible. Security cannot be 100% guaranteed after the review or even if the review will find any problems with your smart contracts. Subsequent security reviews, bug bounty programs and on-chain monitoring are strongly recommended.

## About **Dojo Chip**

Description: “Dojo Chip is an ERC-20 project that has a community filled with AI fanatics. Their team hopes to provide security to the space through a transaction vetting process. They are looking to build a payment processing system which will allow users to go from credit/debit to Crypto without requiring hot wallets such as MetaMask.”

Telegram: https://t.me/dojochipk
Twitter: https://twitter.com/DojoChipERC
Website: https://dojochip.io

Contract Address: [0xc0e24cc5162176fba60108f40d0ffe3bfff73ed6](https://etherscan.io/address/0xc0e24cc5162176fba60108f40d0ffe3bfff73ed6#code)

# Security Assessment Summary

## Scope

The following smart contracts were in the scope of the audit:

- `DojoCHIP`, which is the $dojo ERC20 token contract.

The following number of issues were found, categorized by their severity:
- Critical: 
- High: 
- Medium: 
- Low: 
- Informational: 

---

## Findings

### [C-01] Inconsistent balances, reflections, and total supply
The Dojo CHIP contract calculates user token balances by multiplying user reflections by the ratio of total reflections to total tokens (aka total supply).

The `_getRate()` function calculates the ratio of reflections to tokens returning the total reflections accrued and total tokens using the following formula:
$$
\begin{gather*}
    \textcolor{Red}{\_getRate()}
    =
    \frac{\textcolor{RoyalBlue}{\_rTotal}}{\textcolor{OliveGreen}{\_tTotal}}
\end{gather*}
$$

The `balanceOf()` function calculates user tokens by multiplying user reflections by the ratio of total tokens to total reflections using the following formula:

$$
\begin{gather*}
    \textcolor{Green}{balanceOf(\textcolor{black}{user})}
    =
    \frac{\textcolor{RoyalBlue}{\_rOwned[\textcolor{Black}{user}]}}{\frac{\textcolor{RoyalBlue}{\_rTotal}}{\textcolor{Green}{\_tTotal}}}
    =
    \left( 
        \frac{\textcolor{RoyalBlue}{\_rOwned[\textcolor{Black}{user}]}}{1}*
        \frac{\textcolor{Green}{\_tTotal}}{\textcolor{RoyalBlue}{\_rTotal}}
    \right)
    =
    \frac{\textcolor{RoyalBlue}{\_rOwned[\textcolor{Black}{user}]} * \textcolor{Green}{\_tTotal}}{\textcolor{RoyalBlue}{\_rTotal}}
\end{gather*}
$$

In essence, you solve for user tokens by dividing user reflections by total reflections and multiplying the result by total tokens. Like variables cancel out.

If a buy or sell occurs and reflections are taken, then `_rTotal` is decreased by the reflection fee. When `_rTotal` is decreased, the reflections are distributed to all holders using the previously described formulas. This is able to happen because as `_rTotal` becomes smaller, the number of tokens for all increases since the divisor becomes smaller.

**Example Balance Calculations**
Let's imagine an scenario where ***gucci*** has accrued 1,000 personal reflections, with total tokens at 9,000,000 and total reflections at 1,000,000,000.
1. $\textcolor{RoyalBlue}{\_rOwned[\textcolor{Black}{gucci}]} = 1,000$
2. $\textcolor{Green}{\_tTotal} = 9,000,000$ 
3. $\textcolor{RoyalBlue}{\_rTotal} = 1,000,000,000$

Plugging these values into the previously defined formulas brings ***gucci***'s balance to:   
$$
\begin{gather*}
    \textcolor{Green}{balanceOf(\textcolor{Black}{gucci})}
    =
    \frac{\textcolor{RoyalBlue}{\textcolor{RoyalBlue}{1,000}} * \textcolor{Green}{9,000,000}}{\textcolor{RoyalBlue}{1,000,000,000}}
    =
    \text{\textcolor{Green}{9 tokens}}
\end{gather*}
$$
If `_rTotal` were decreased to 900,000,000 after the deduction of reflection fees then ***gucci***'s balance is adjusted to:    
$$
\begin{gather*}
    \textcolor{Green}{balanceOf(\textcolor{Black}{gucci})}
    =
    \frac{\textcolor{RoyalBlue}{\textcolor{RoyalBlue}{1,000}} * \textcolor{Green}{9,000,000}}{\textcolor{RoyalBlue}{900,000,000}}
    =
    \text{\textcolor{Green}{10 tokens}}
\end{gather*}
$$
As reflection fees are deducted from `_rTotal`, all token balances increase accordingly.

If a decrease in total supply is not accounted for when calculating reflections, then users will end up with more tokens than they should and the sum of all balances will be greater than the true total supply. ​Unfortunately the `_tTotal` variable used in the previous formulas is constant, despite the presence of burning functionality in the contract. This is due to the fact that burned token amounts are deducted from `_tSupply`, not `_tTotal`.  As a result, `_tTotal` does not accurately represent the true total supply which leads to incorrect calculations for transfer amounts, fees, reflections, and overall balances.

If `_tSupply` and `_tTotal` are not kept in sync, the total reflections to total tokens ratio is broken. Any reflections calculated during transactions will be higher since `_rTotal` (total reflections) is always decreasing while `_tTotal` (original total supply) is constant. The `_tSupply` variable is the true total supply of the token since it deducts burned token amounts and the `totalSupply()` function returns its value.

**Recommendation**
There are two options to mend or fix the balance, reflection, and total supply discrepancies:
1. Turn off burn and reflection fees by setting `buyBurnFee`, `buyReflectionFee`, `sellBurnFee`, and `sellReflectionFee` to zero to prevent further losses. Effectively convert the contract to a simple fee token that only takes fees during buys or sells for the treasury since these fees are unaffected by the reflection and burn fees.
**NOTE:** All existing balances and reflection amounts cannot be corrected and could still lead to future issues. Even so, this option is cheaper and easier than completely relaunching the token.

2. Relaunch the token, using `_tSupply` in place of `_tTotal`. Unsure what the ramifications of selling off completely would yield. Depending on the Uniswap accounting all liquidity might not be accessible because the returned total supply is not the actual total supply.

### [C-01] Improper amounts of tokens burned and reflected 
On transfers that accrue fees, the total amount of tokens taken for burn and reflection fees is passed to the `burnAndReflect()` function. Inside this function this total is split: half of the tokens are burned and the remaining half of the tokens are subtracted from total reflections.

The `burnAndReflect()` function will always burn half of the sum of `tokensForReflections` and `tokensForBurn` even if `tokensForReflections` is greater than `tokensForBurn` and vice versa. As a result the function’s behavior is:
1. Inconsistent with the actual burn and reflection fees taken
2. Incorrectly adjusts the total tokens reflected and burned

Only `tokensForBurns` worth of tokens should be burned and only `tokensForReflections` worth of tokens should be reflected.

**Recommendation**
Turn off burn and reflection fees by setting `buyBurnFee`, `buyReflectionFee`, `sellBurnFee`, and `sellReflectionFee` to zero to prevent further losses. Effectively convert the contract to a simple fee token that only takes fees during buys or sells for the treasury.