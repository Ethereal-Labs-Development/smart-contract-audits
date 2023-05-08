// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../lib/forge-std/src/Test.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { Beehive } from "../src/projects/subscribee/Beehive.sol";
import { Subscribee } from "../src/projects/subscribee/Subscribee.sol";

/// @notice Unit tests to validate Subscribee contract functionality and implementation.
contract SubscribeeTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    Subscribee subscribee;
    Beehive beehive;

    function setUp() public {
        // Deploy the Beehive contract
        beehive = new Beehive(
            address(this),
            69
        );

        // Deploy Subscribee contract via Beehive
        beehive.deploySubscribeeContract(
            address(this), // operator
            "Subscription Test" // slug
        );

        // Get reference to deployed Subscribee contract
        subscribee = Subscribee(beehive.slugs("Subscription Test"));
        
        // Create test plan, with planId 0, as owner
        subscribee.createPlan(USDC, 10 * 10**6, 2 days);
    }

    /// @notice Test concept that collectSubscriptionPayment will fail if one user has already paid
    /// @dev Having a list of many users with payments due at the same time is extremely unlikely. 
    /// As a result, having a function to batch the payment collection process could result in wasted 
    /// gas and or simply never succeed for multiple users.
    function test_subscribee_collectSubscriptionPayment_OneNotDueYet() public {
        address subscriberOne = makeAddr("Subscriber One");
        address subscriberTwo = makeAddr("Subscriber Two");

        // Give both subscribers 100 USDC each to pay for subscriptions
        deal(USDC, subscriberOne, 100 * 10**6);
        deal(USDC, subscriberTwo, 100 * 10**6);

        // Subscriber one subscribes and pays for subscription plan 0
        vm.startPrank(subscriberOne);
        // Approve subscription amount to be taken by subscription contract
        IERC20(USDC).approve(address(subscribee), 10 * 10**6);
        // Subscribe and pay initial subscription amount
        subscribee.subscribe(0);
        vm.stopPrank();

        // Subscriber two subscribes and pays for subscription plan 0
        vm.startPrank(subscriberTwo);
        // Approve subscription amount to be taken by subscription contract
        IERC20(USDC).approve(address(subscribee), 10 * 10**6);
        // Subscribe and pay initial subscription amount
        subscribee.subscribe(0);
        vm.stopPrank();

        // Warp ahead to next subscription due date and pay for subscription
        vm.warp(block.timestamp + 2.1 days);

        // Subscriber two pays for subscription plan 0 when its due
        vm.startPrank(subscriberTwo);
        // Since USDC is not a special token, the entire subscription amount
        // gets sent to the owner of the Subscribee contract, no splitting
        IERC20(USDC).approve(address(subscribee), 10 * 10**6);
        // Pay recurring subscription amount
        subscribee.paySubscription(0);
        vm.stopPrank();

        // Owner attempts to collect payment from subscribers, where one has already paid
        Subscribee.UserObject[] memory subs = new Subscribee.UserObject[](2);
        subs[0] = Subscribee.UserObject(subscriberOne, 0);
        subs[1] = Subscribee.UserObject(subscriberTwo, 0);

        // Approve payment for subscriberOne, but not subscriberTwo since it should fail
        vm.prank(subscriberOne);
        IERC20(USDC).approve(address(subscribee), 10 * 10**6);

        // Since subscriberTwo already paid for their subscription, the entire transaction
        // to collect subscription payments from all subscribers will revert.
        vm.expectRevert("not due yet");
        subscribee.collectSubscriptionPayments(subs);
    }

}