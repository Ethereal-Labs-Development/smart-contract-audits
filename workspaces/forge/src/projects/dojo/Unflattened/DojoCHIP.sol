// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Parents
import { ERC20 } from "./ERC20.sol";
import { Ownable } from "./Ownable.sol";

// Libraries
// @audit SafeMath is used in DojoCHIP and ERC20 contracts.
import { SafeMath } from "./SafeMath.sol";

// Interfaces
import { IUniswapV2Router02 } from "./IUniswapV2Router02.sol"; /// @notice Includes IUniswapV2Router01 interface.
import { IUniswapV2Factory } from "./IUniswapV2Factory.sol";
// @audit This interface is included in the flattened contract but never used.
import { IUniswapV2Pair } from "./IUniswapV2Pair.sol"; 

contract DojoCHIP is ERC20, Ownable {
    // @audit Use of deprecated library for Solidity version 0.8.0+
    using SafeMath for uint256;

    mapping (address => uint256) private _rOwned;
    // MAX = 115792089237316195423570985008687907853269984665640564039457584007913129639935
    uint256 constant private MAX = ~uint256(0);
    // _tTotal = 115792089237316195423570985008687907853269984665640564039457584007000000000000
    uint256 constant private _tTotal = 9 * 1e6 * 1e6;
    // @audit This amount is total supply of the token.
    uint256 private _tSupply;
    // _rTotal = 9000000000000
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    
    uint256 public maxTransactionAmount;
    uint256 public maxWallet;
    uint256 public swapTokensAtAmount;

    IUniswapV2Router02 public immutable uniswapV2Router;
    // @audit Unsure why this was not given IUniswapV2Pair interface declaration. The interface is never used though.
    address public immutable uniswapV2Pair;
    address public constant deadAddress = address(0xdead);

    bool private swapping;

    // @audit Unverified contract address.
    address public Treasury;

    bool public limitsInEffect = true;
    // @gas Unnecessary initialization.
    bool public tradingActive = false;
    
     // Anti-bot and anti-whale mappings and variables
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
    bool public transferDelayEnabled = true;

    uint256 public buyTotalFees;
    uint256 public buyTreasuryFee = 28;
    uint256 public buyBurnFee = 1;
    uint256 public buyReflectionFee = 1;
    // uint256 public buyTotalFees = buyTreasuryFee + buyBurnFee + buyReflectionFee;
    
    uint256 public sellTotalFees;
    uint256 public sellTreasuryFee = 28;
    uint256 public sellBurnFee = 1;
    uint256 public sellReflectionFee = 1;
    // uint256 public sellTotalFees = sellTreasuryFee + sellBurnFee + sellReflectionFee;

    uint256 public tokensForTreasury;
    uint256 public tokensForBurn;
    uint256 public tokensForReflections;
    
    uint256 public walletDigit;
    uint256 public transDigit;
    uint256 public delayDigit;
    
    /******************/

    // exclude from fees, max transaction amount and max wallet amount
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) public _isExcludedMaxTransactionAmount;
    mapping (address => bool) public _isExcludedMaxWalletAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    constructor() ERC20("DojoCHIP", "dojo") {
        // @gas Unsure why `uniswapV2Router` is immutable and not constant. This makes sense for `uniswapV2Pair` 
        // since that address might be variable, but the router address never changes unless redeployed by Uniswap.
        // @gas Also unsure why a local variable is used here instead of the state variable.
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        
        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        excludeFromMaxWallet(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;
        
        // @audit Does not use the included IUniswapV2Pair interace.
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        excludeFromMaxWallet(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        // @audit Includes SafeMath but only uses it for certain calculations.
        // @gas Could perform these calculations outside of constructor.
        buyTotalFees = buyTreasuryFee + buyBurnFee + buyReflectionFee;
        sellTotalFees = sellTreasuryFee + sellBurnFee + sellReflectionFee;
        
        Treasury = 0x3d37743CC53fa989D910c13aE05AAfAc0d0f489b; 
        _rOwned[_msgSender()] = _rTotal;
        _tSupply = _tTotal;

        // @gas Could assign these values outside of the constructor.
        walletDigit = 1;    // walletDigit / 100 = wallet fee 0-100%
        transDigit = 1;     // transDigit / 100 = transfer fee 0-100%
        delayDigit = 1;     // delayDigit = # of blocks to wait before next transfer
        
        // @gas Could perform these calculations outside of constructor.
        maxTransactionAmount =_tSupply * transDigit / 100;
        swapTokensAtAmount = _tSupply * 5 / 10000; // 0.05% swap wallet;
        maxWallet = _tSupply * walletDigit / 100;

        // @gas Could have used private mapping to save from extraneous function call.
        // Assumed to be safe to use the mapping directly inside the constructor.
        // For example _isExcludedFromFees[owner()] = true; etc.
        // exclude from paying fees or having max transaction amount, max wallet amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);
        
        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        excludeFromMaxWallet(owner(), true);
        excludeFromMaxWallet(address(this), true);
        excludeFromMaxWallet(address(0xdead), true);

        // @audit Why is the owner approving uniswap router to take the entirety of the 
        _approve(owner(), address(uniswapV2Router), _tSupply);
        _mint(msg.sender, _tSupply);
    }

    receive() external payable {}

    // once enabled, can never be turned off
    function enableTrading() external onlyOwner {
        tradingActive = true;
    }
    
    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        return true;
    }

     // change the minimum amount of tokens to swap
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner returns (bool) {
  	    require(newAmount >= (totalSupply() * 1 / 100000) / 1e6, "Swap amount cannot be lower than 0.001% total supply.");
  	    require(newAmount <= (totalSupply() * 5 / 1000) / 1e6, "Swap amount cannot be higher than 0.5% total supply.");
  	    swapTokensAtAmount = newAmount * (10**6);
  	    return true;
  	}
    
    function updateTransDigit(uint256 newNum) external onlyOwner {
        require(newNum >= 1);
        transDigit = newNum;
        updateLimits();
    }

    function updateWalletDigit(uint256 newNum) external onlyOwner {
        require(newNum >= 1);
        walletDigit = newNum;
        updateLimits();
    }

    //
    function updateDelayDigit(uint256 newNum) external onlyOwner{
        delayDigit = newNum;
    }
    
    function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function excludeFromMaxWallet(address updAds, bool isEx) public onlyOwner {
        _isExcludedMaxWalletAmount[updAds] = isEx;
    }

    // @audit Buy fees cannot return to starting levels once updated. Total buy fees are 30% on launch.
    function updateBuyFees(uint256 _treasuryFee, uint256 _burnFee, uint256 _reflectionFee) external onlyOwner {
        buyTreasuryFee = _treasuryFee;
        buyBurnFee = _burnFee;
        buyReflectionFee = _reflectionFee;
        buyTotalFees = buyTreasuryFee + buyBurnFee + buyReflectionFee;
        require(buyTotalFees <= 10, "Must keep fees at 10% or less");
    }
    
    // @audit Sell fees cannot return to starting levels once updated. Total sell fees are 30% on launch.
    function updateSellFees(uint256 _treasuryFee, uint256 _burnFee, uint256 _reflectionFee) external onlyOwner {
        sellTreasuryFee = _treasuryFee;
        sellBurnFee = _burnFee;
        sellReflectionFee = _reflectionFee;
        sellTotalFees = sellTreasuryFee + sellBurnFee + sellReflectionFee;
        require(sellTotalFees <= 10, "Must keep fees at 10% or less");
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

    }

    // @audit Missing zero address check.
    function updateTreasuryWallet(address newTreasuryWallet) external onlyOwner {
        Treasury = newTreasuryWallet;
    }

    function updateLimits() private {
        maxTransactionAmount = _tSupply * transDigit / 100;
        swapTokensAtAmount = _tSupply * 1 / 10000; // 0.01% swap wallet;
        maxWallet = _tSupply * walletDigit / 100;
    }

    function isExcludedFromFees(address account) external view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !swapping
            ) {
                if (!tradingActive) {
                    require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading is not active.");
                }
 
                if (transferDelayEnabled){
                    if (to != owner() && to != address(uniswapV2Router) && to != address(uniswapV2Pair)){
                        require(_holderLastTransferTimestamp[tx.origin] < block.number, "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed.");
                        _holderLastTransferTimestamp[tx.origin] = block.number + delayDigit;
                    }
                }

                // when buy
                if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                    require(amount <= maxTransactionAmount, "Buy transfer amount exceeds the maxTransactionAmount.");
                }

                if (!_isExcludedMaxTransactionAmount[from]) {
                    require(amount <= maxTransactionAmount, "transfer amount exceeds the maxTransactionAmount.");
                }

                if (!_isExcludedMaxWalletAmount[to]) {
                    require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
                }
            }
        }

		uint256 contractTokenBalance = balanceOf(address(this));
        
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if ( 
            canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;
            
            swapBack();

            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        
        uint256 fees = 0;
        uint256 reflectionFee = 0;
 
        if (takeFee){

            // on buy
            if (automatedMarketMakerPairs[from] && to != address(uniswapV2Router)) {
                fees = amount.mul(buyTotalFees).div(100);
                getTokensForFees(amount, buyTreasuryFee, buyBurnFee, buyReflectionFee);
            }

            // on sell
            else if (automatedMarketMakerPairs[to] && from != address(uniswapV2Router)) {
                    fees = amount.mul(sellTotalFees).div(100);
                    getTokensForFees(amount, sellTreasuryFee, sellBurnFee, sellReflectionFee);
            }

            if (fees > 0) {
                _tokenTransfer(from, address(this), fees, 0);
                uint256 refiAmount = tokensForBurn + tokensForReflections;
                bool refiAndBurn = refiAmount > 0;

                if(refiAndBurn){
                    burnAndReflect(refiAmount);
                }

            }

            amount -= fees;
        }

        _tokenTransfer(from, to, amount, reflectionFee);
    }

    function getTokensForFees(uint256 _amount, uint256 _treasuryFee, uint256 _burnFee, uint256 _reflectionFee) private {
        tokensForTreasury += _amount.mul(_treasuryFee).div(100);
        tokensForBurn += _amount.mul(_burnFee).div(100);
        tokensForReflections += _amount.mul(_reflectionFee).div(100);
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        bool success;
        
        if(contractBalance == 0) {return;}

        swapTokensForEth(contractBalance); 

        tokensForTreasury = 0;

        // @audit Does not validate success of the transfer to the Treasury.
        (success,) = address(Treasury).call{value: address(this).balance}("");
    }

    // Reflection
    function totalSupply() public view override returns (uint256) {
        return _tSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function tokenFromReflection(uint256 rAmount) private view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, uint256 reflectionFee) private {      
        _transferStandard(sender, recipient, amount, reflectionFee);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount, uint256 reflectionFee) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount, reflectionFee);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount, uint256 reflectionFee) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount, reflectionFee);
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    function _getTValues(uint256 tAmount, uint256 reflectionFee) private pure returns (uint256, uint256) {
        uint256 tFee = tAmount.mul(reflectionFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee);
        return (tTransferAmount, tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        // @audit This returns the exact same values. If statement does nothing.
        // @gas Unnecessary if statement and operations, should just return state variables.
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function burnAndReflect(uint256 _amount) private {
        _tokenTransfer(address(this), deadAddress, _amount, 50);
        _tSupply -= _amount.div(2);
        tokensForReflections = 0;
        tokensForBurn = 0;
        updateLimits();
    }


}