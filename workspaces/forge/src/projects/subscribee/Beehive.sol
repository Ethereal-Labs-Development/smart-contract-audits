// SPDX-License-Identifier: Business Source License 1.1
pragma solidity ^0.8.8;

import "../../bases/ReentrancyGuard.sol";
import "./Subscribee.sol"; 

contract Beehive is Ownable{

  // Variables and Mappings

  address public operator;
  uint256 public slugFee;

  mapping(string => address) public slugs;
  mapping(address => bool) public verifiedContract;
  mapping(address => bool) public specialToken;

  // Events

  event NewContract(
    address contractAddress,
    string slug,
    uint256 time
  );

  event SlugChanged(
    address contractAddress,
    string oldSlug,
    string newSlug
  );

  // Structs

  struct TokenToCollect {
    address contractAddress;
    address sendToAddress;
    address tokenAddress;
  }

  // Modifiers

  modifier onlyOperatorOrOwner() {
    require(msg.sender == operator || msg.sender == owner(), 'Huh?');
    _;
  }

  // Constructor

  constructor(address operatorAddress, uint256 newSlugFee) {
    operator = operatorAddress;
    slugFee = newSlugFee;
  }

  // Methods

  function toggleSpecialToken(address tokenAddress) external onlyOperatorOrOwner{
    if( specialToken[tokenAddress] ){
      specialToken[tokenAddress] = false;
    }else{
      specialToken[tokenAddress] = true;
    }
  }

  function setOperator(address newOperator) external onlyOperatorOrOwner{
    operator = newOperator;
  }

  function setSlugFee(uint256 newSlugFee) external onlyOperatorOrOwner{
    slugFee = newSlugFee;
  }

  function collectSlugFees(address toAddress) external onlyOperatorOrOwner{
    payable(toAddress).transfer(address(this).balance);
  }

  function collectTokenFees(TokenToCollect[] memory collections) external onlyOperatorOrOwner{
    for(uint i = 0; i < collections.length; i++){
      Subscribee subscribeeContract = Subscribee(collections[i].contractAddress);
      subscribeeContract.collectToken(collections[i].tokenAddress, collections[i].sendToAddress);
    }
  }

  function changeSlug(string memory oldslug, string memory newslug) external payable{
    Subscribee subscribeeContract = Subscribee(slugs[oldslug]);
    require(subscribeeContract.owner() == msg.sender || subscribeeContract.operator() == msg.sender, "Only the Owner or Operator of the contract can do this");
    require(slugs[newslug] == address(0), "Slug has been taken");
    require(msg.value == slugFee, "Please pay the appropiate amount...");

    slugs[newslug] = slugs[oldslug];
    emit SlugChanged(slugs[oldslug], oldslug, newslug);
    delete slugs[oldslug];
  }

  function deploySubscribeeContract(address operatorAddress, string memory slug) external{
    require(slugs[slug] == address(0), "Slug has been taken");

    Subscribee newContract = new Subscribee( operatorAddress, address(this) );
    newContract.transferOwnership(msg.sender);

    address contractAddress = address(newContract);
    slugs[slug] = contractAddress;
    verifiedContract[contractAddress] = true;

    emit NewContract(contractAddress, slug, block.timestamp);
  }

}