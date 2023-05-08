// SPDX-License-Identifier: Business Source License 1.1
pragma solidity ^0.8.8;

import "../../interfaces/IERC20.sol";
import "../../bases/Ownable.sol";
import "../../bases/ReentrancyGuard.sol";

interface IBeehive {
    function owner() external view returns (address);
    function operator() external view returns (address);
    function specialToken(address) external view returns (bool);
}

contract Subscribee is Ownable, ReentrancyGuard{

  uint16 public nextPlanId;

  mapping(uint16 => Plan) public plans;
  mapping(uint16 => mapping(address => Subscription)) public subscriptions;

  address public operator;
  address public beehive;

  // Structs

  struct Plan {
    address token;
    uint256 amount;
    uint32 frequency;
    bool stopped;
    bool limited;
  }

  struct Subscription {
    uint256 start;
    uint256 nextPayment;
    bool stopped;
  }

  struct UserObject {
    address subscriber;
    uint16 planId;
  }

  // Events

  event PlanCreated(
    address token,
    uint256 amount,
    uint32 frequency
  );

  event SubscriptionCreated(
    address subscriber,
    uint16 planId,
    uint256 date
  );

  event SubscriptionDeleted(
    address subscriber,
    uint16 planId,
    uint256 date
  );

  event SubscriptionPayment(
    address from,
    address token,
    uint256 amount,
    uint16 planId,
    uint256 date
  );

  // Modifiers

  modifier onlyOperatorOrOwner() {
    require(
      msg.sender == operator ||
      msg.sender == owner(), 'Huh?'
    );
    _;
  }

  modifier onlyBeehive() {
    require(
      msg.sender == IBeehive(beehive).owner() ||
      msg.sender == IBeehive(beehive).operator() ||
      msg.sender == beehive, "You No Bzzz!"
    );
    _;
  }

  // Constructor

  constructor(address operatorAddress, address beehiveAddress) {
    operator = operatorAddress;
    beehive = beehiveAddress;
  }

  // External Functions

  function subscribe(uint16 planId) external {
    _firstSubscriptionPayment(planId);
  }

  function toggleStop(uint16 planId) external {
    _stop(planId);
  }

  function deleteSubscription(uint16 planId) external {
    _delete(msg.sender, planId);
  }

  function paySubscription(uint16 planId) external {
    _makeSubscriptionPayment(msg.sender, planId);
  }

  function collectToken(address tokenToCollect, address recieverAddress) external onlyBeehive nonReentrant{
    IERC20 token = IERC20(tokenToCollect);
    uint256 balance = token.balanceOf( address(this) );
    require(token.transfer(recieverAddress, balance));
  }

  function setOperator(address newOperator) external onlyOperatorOrOwner{
    operator = newOperator;
  }

  function togglePlanStop(uint16 planId) external onlyOperatorOrOwner{
    if(plans[planId].stopped){
      plans[planId].stopped = false;
    }else{
      plans[planId].stopped = true;
    }
  }

  function togglePlanLimited(uint16 planId) external onlyOperatorOrOwner{
    if(plans[planId].limited){
      plans[planId].limited = false;
    }else{
      plans[planId].limited = true;
    }
  }

  function createPlan(address token, uint256 amount, uint32 frequency) external onlyOperatorOrOwner{
    require(token != address(0), 'address cannot be null address');
    require(amount > 0, 'amount needs to be > 0');
    require(frequency >= 86400, 'frequency needs to be greater or equal to 24 hours');
    require(nextPlanId < 65535, 'You have created too many plans');

    plans[nextPlanId] = Plan(
      token,
      amount,
      frequency,
      false,
      false
    );

    emit PlanCreated(token, amount, frequency);
    nextPlanId++;
  }

  function collectSubscriptionPayments(UserObject[] memory users) external onlyOperatorOrOwner nonReentrant{
    for(uint i = 0; i < users.length; i++){
      address subscriber = users[i].subscriber;
      uint16 planId = users[i].planId;
      _makeSubscriptionPayment(subscriber, planId);
    }
  }

  function multiDelete(UserObject[] memory users) external onlyOperatorOrOwner{
    for(uint i = 0; i < users.length; i++){
      address subscriber = users[i].subscriber;
      uint16 planId = users[i].planId;
      _delete(subscriber, planId);
    }
  }

  // Private Functions

  function _firstSubscriptionPayment(uint16 planId) private {
    // call from storage
    Plan storage plan = plans[planId];

    require(plan.token != address(0), 'This plan does not exist');
    require(!plan.stopped, 'Plan is Stopped');
    require(!plan.limited, 'Plan is Limited');

    _collectTokenPayment(msg.sender, plan.token, plan.amount);

    subscriptions[planId][msg.sender] = Subscription(
      block.timestamp,
      block.timestamp + plan.frequency,
      false
    );

    emit SubscriptionCreated(
      msg.sender,
      planId,
      block.timestamp
    );

    // emit Payment Receipt event
      emit SubscriptionPayment(
        msg.sender,
        plan.token,
        plan.amount,
        planId,
        block.timestamp
      );
    }

  function _makeSubscriptionPayment(address subscriber, uint16 planId) private {
      // call from storage
    Plan storage plan = plans[planId];
    Subscription storage subscription = subscriptions[planId][subscriber];

    require(!plan.stopped, 'Plan is stopped');
    require(subscription.start != 0, 'this subscription does not exist');
    require(block.timestamp > subscription.nextPayment, 'not due yet');
    require(!subscription.stopped, 'Subscriber opted to stop payments; contact user or delete subscription');

    _collectTokenPayment(subscriber, plan.token, plan.amount);

    subscription.nextPayment = subscription.nextPayment + plan.frequency;


      // emit Payment Receipt event
      emit SubscriptionPayment(
        subscriber,
        plan.token,
        plan.amount,
        planId,
        block.timestamp
      );
    }

  function _collectTokenPayment(address sender, address tokenAddress, uint256 amount) private {
    uint256 fee = amount / 67;
    bool isSpecialToken = IBeehive(beehive).specialToken(tokenAddress);
    address beehiveAdmin = isSpecialToken ? address(this) : IBeehive(beehive).owner();

    // set Token
    IERC20 token = IERC20(tokenAddress);

    // @audit One approval from the subscriber is required for this transaction to succeed. It could 
    // be better for the fee and payment to be taken from the Subscribee contract itself. The payment
    // could come back to Subscribee contracts allowing the owners and beehive admin to withdraw them
    // later without issues. Can prompt the user to perform one transfer into Subscribee contracts
    // which is simpler and safer to produce than rolling approvals from subscribers.
    // @audit However, 'permit' could the potentially replace both of these processes entirely.

    // send to Contract Owner & BeeHive
    // @audit 'owner()' usually refers to the deployer of this contract, but ownership is transferred
    // to the msg.sender who deployed via Beehive and 'IBeehive(beehive).owner()' returns the address
    // that owns the Beehive contract.
    require(token.transferFrom(sender, owner(), amount - fee));
    require(token.transferFrom(sender, beehiveAdmin, fee));

  }

  function _delete(address user, uint16 planId) private {
    // Grab user subscription data & check if it exists
    Subscription storage subscription = subscriptions[planId][user];
    require(subscription.start != 0, 'this subscription does not exist');

    // Delete subscription and emit delete event
    delete subscriptions[planId][user];

    emit SubscriptionDeleted(user, planId, block.timestamp);
  }

  function _stop(uint16 planId) private {
    // Grab user subscription data & check if it exists
    Subscription storage subscription = subscriptions[planId][msg.sender];
    require(subscription.start != 0, 'this subscription does not exist');

    // Check if user owes funds and is trying to stop, will delete
    if(subscription.nextPayment < block.timestamp && subscription.stopped == false){
      _delete(msg.sender, planId);
      return;
    }

    if(subscription.stopped){
      subscription.stopped = false;
    }else{
      subscription.stopped = true;
    }

  }
}