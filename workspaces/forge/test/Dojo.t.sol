// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../lib/forge-std/src/Test.sol";
import { DojoCHIP } from "../src/projects/dojo/Unflattened/DojoCHIP.sol";
import { IUniswapV2Router02 } from "../src/projects/dojo/Unflattened/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../src/projects/dojo/Unflattened/IUniswapV2Pair.sol";

contract DojoTest is Test {
    DojoCHIP public dojo;
    IUniswapV2Router02 public constant uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Pair public uniswapV2Pair;

    function setUp() public {
        dojo = new DojoCHIP();

        // give this contract ether
        vm.deal(address(this), 1000 ether);
        vm.label(address(this), "Owner");

        // get the pair address created with contract deployment
        uniswapV2Pair = IUniswapV2Pair(dojo.uniswapV2Pair());
        vm.label(address(uniswapV2Pair), "Pair");

        // add liquidity to the Dojo, WETH pair
        // (450_000_000_000 dojo, 100 ether)
        uniswapV2Router.addLiquidityETH{value: 100 ether}(address(dojo), 450_000_000_000, 450_000_000_000, 100 ether, address(this), block.timestamp+500);
    }

    /// @notice Test which logs state set in the constructor.
    function test_dojo_Constructor() public {
        emit log_named_uint("Total supply", dojo.totalSupply());
        emit log_named_uint("Owner balance", dojo.balanceOf(address(this)));

        emit log_named_uint("Maximum transaction amount", dojo.maxTransactionAmount());
        emit log_named_uint("Swap tokens at amount", dojo.swapTokensAtAmount());
        emit log_named_uint("Maximum wallet balance", dojo.maxWallet());
    }

    /// @notice Test proof of concept for endless lock of transfers.
    function test_dojo_updateDelayDigit_LockTransfers() public {
        // average number of blocks mined per day
        uint256 blocksMined = 7066;
        // maximum number of blocks user must wait before next transfer
        uint256 maxDelay = type(uint256).max;

        uint256 numYears = maxDelay / (blocksMined * 365);
        emit log_named_uint("Potential wait time in years", numYears);
    }

    /// @notice Test that total supply is not accurately reflected with burn and reflection fees.
    function test_dojo_transfer_IncorrectSupply() public {
        address seller = makeAddr("Seller");
        // equivalent to .001% of owner's balance after setting up pair liquidity
        uint256 amountToSell = (dojo.balanceOf(address(this)) / 10000);
        // give tokens tax free from owner to seller
        dojo.transfer(seller, amountToSell);

        // at this point only the uniswapV2Pair and owner have any dojo tokens
        uint256 ownerBalBefore = dojo.balanceOf(address(this));
        uint256 pairBalBefore = dojo.balanceOf(address(uniswapV2Pair));
        uint256 sellerBalBefore = dojo.balanceOf(seller);
        assertEq(ownerBalBefore + pairBalBefore + sellerBalBefore, dojo.totalSupply());

        // remove limits
        dojo.removeLimits();
        
        vm.startPrank(seller);
        // seller does not have any ether and is not excluded from fees
        assertEq(seller.balance, 0);
        assertEq(dojo._isExcludedFromFees(seller), false);

        // create uniswap path of DojoCHIP -> WETH
        address[] memory path = new address[](2);
        path[0] = address(dojo);
        path[1] = uniswapV2Router.WETH();

        // approve token amount
        dojo.approve(address(uniswapV2Router), amountToSell);

        // swap the tokens for ether
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSell,
            0, // accept any amount of ether
            path,
            seller, // send ether to the seller
            block.timestamp
        );

        // seller should have received ether for sold tokens
        assertGt(seller.balance, 0);
        assertLt(dojo.balanceOf(seller), amountToSell);
        vm.stopPrank();

        // after selling some tokens, the total number of circulating tokens 
        // drops below the "reported" total supply.
        uint256 ownerBalAfter = dojo.balanceOf(address(this));
        uint256 pairBalAfter = dojo.balanceOf(address(uniswapV2Pair));
        uint256 sellerBalAfter = dojo.balanceOf(seller);
        assertLt(ownerBalAfter + pairBalAfter + sellerBalAfter, dojo.totalSupply());
    }

}