// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Prediction Market
 * @dev A decentralized prediction market where users can bet on future events and outcomes
 * @author Your Name
 */
contract Prediction {
    
    // Struct to represent a prediction market
    struct Market {
        uint256 id;
        string question;
        string[] options;
        uint256[] optionBets;
        uint256 totalBets;
        uint256 endTime;
        uint256 winningOption;
        bool resolved;
        address creator;
        mapping(address => mapping(uint256 => uint256)) userBets;
        mapping(address => bool) hasClaimed;
    }
    
    // State variables
    mapping(uint256 => Market) public markets;
    uint256 public marketCounter;
    uint256 public constant PLATFORM_FEE = 2; // 2% platform fee
    address public owner;
    uint256 public totalPlatformFees;
    
    // Events
    event MarketCreated(uint256 indexed marketId, string question, address indexed creator);
    event BetPlaced(uint256 indexed marketId, address indexed bettor, uint256 option, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOption);
    event WinningsClaimed(uint256 indexed marketId, address indexed winner, uint256 amount);
    event PlatformFeesWithdrawn(address indexed owner, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier marketExists(uint256 _marketId) {
        require(_marketId < marketCounter, "Market does not exist");
        _;
    }
    
    modifier marketActive(uint256 _marketId) {
        require(block.timestamp < markets[_marketId].endTime, "Market has ended");
        require(!markets[_marketId].resolved, "Market already resolved");
        _;
    }
    
    modifier marketEnded(uint256 _marketId) {
        require(block.timestamp >= markets[_marketId].endTime, "Market has not ended yet");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Create a new prediction market
     * @param _question The question for the prediction market
     * @param _options Array of possible outcomes
     * @param _duration Duration of the market in seconds
     */
    function createMarket(
        string memory _question,
        string[] memory _options,
        uint256 _duration
    ) external {
        require(bytes(_question).length > 0, "Question cannot be empty");
        require(_options.length >= 2, "At least 2 options required");
        require(_duration > 0, "Duration must be positive");
        
        uint256 marketId = marketCounter++;
        Market storage newMarket = markets[marketId];
        
        newMarket.id = marketId;
        newMarket.question = _question;
        newMarket.options = _options;
        newMarket.optionBets = new uint256[](_options.length);
        newMarket.totalBets = 0;
        newMarket.endTime = block.timestamp + _duration;
        newMarket.resolved = false;
        newMarket.creator = msg.sender;
        
        emit MarketCreated(marketId, _question, msg.sender);
    }
    
    /**
     * @dev Place a bet on a specific option in a market
     * @param _marketId The ID of the market
     * @param _option The option index to bet on
     */
    function placeBet(uint256 _marketId, uint256 _option) 
        external 
        payable 
        marketExists(_marketId) 
        marketActive(_marketId) 
    {
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(_option < markets[_marketId].options.length, "Invalid option");
        
        Market storage market = markets[_marketId];
        
        market.userBets[msg.sender][_option] += msg.value;
        market.optionBets[_option] += msg.value;
        market.totalBets += msg.value;
        
        emit BetPlaced(_marketId, msg.sender, _option, msg.value);
    }
    
    /**
     * @dev Resolve a market by setting the winning option
     * @param _marketId The ID of the market to resolve
     * @param _winningOption The index of the winning option
     */
    function resolveMarket(uint256 _marketId, uint256 _winningOption) 
        external 
        marketExists(_marketId) 
        marketEnded(_marketId) 
    {
        require(msg.sender == markets[_marketId].creator || msg.sender == owner, "Only creator or owner can resolve");
        require(!markets[_marketId].resolved, "Market already resolved");
        require(_winningOption < markets[_marketId].options.length, "Invalid winning option");
        
        Market storage market = markets[_marketId];
        market.winningOption = _winningOption;
        market.resolved = true;
        
        emit MarketResolved(_marketId, _winningOption);
    }
    
    /**
     * @dev Claim winnings from a resolved market
     * @param _marketId The ID of the resolved market
     */
    function claimWinnings(uint256 _marketId) 
        external 
        marketExists(_marketId) 
    {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved yet");
        require(!market.hasClaimed[msg.sender], "Already claimed");
        
        uint256 userBet = market.userBets[msg.sender][market.winningOption];
        require(userBet > 0, "No winning bet found");
        
        uint256 winningPoolTotal = market.optionBets[market.winningOption];
        require(winningPoolTotal > 0, "No bets on winning option");
        
        // Calculate user's share of the total pool minus platform fee
        uint256 totalPool = market.totalBets;
        uint256 platformFee = (totalPool * PLATFORM_FEE) / 100;
        uint256 distributionPool = totalPool - platformFee;
        
        uint256 winnings = (userBet * distributionPool) / winningPoolTotal;
        
        market.hasClaimed[msg.sender] = true;
        totalPlatformFees += (userBet * platformFee) / winningPoolTotal;
        
        payable(msg.sender).transfer(winnings);
        emit WinningsClaimed(_marketId, msg.sender, winnings);
    }
    
    /**
     * @dev Get market information
     * @param _marketId The ID of the market
     */
    function getMarketInfo(uint256 _marketId) 
        external 
        view 
        marketExists(_marketId) 
        returns (
            string memory question,
            string[] memory options,
            uint256[] memory optionBets,
            uint256 totalBets,
            uint256 endTime,
            bool resolved,
            uint256 winningOption
        ) 
    {
        Market storage market = markets[_marketId];
        return (
            market.question,
            market.options,
            market.optionBets,
            market.totalBets,
            market.endTime,
            market.resolved,
            market.winningOption
        );
    }
    
    /**
     * @dev Get user's bet information for a specific market
     * @param _marketId The ID of the market
     * @param _user The address of the user
     */
    function getUserBets(uint256 _marketId, address _user) 
        external 
        view 
        marketExists(_marketId) 
        returns (uint256[] memory userBets) 
    {
        Market storage market = markets[_marketId];
        userBets = new uint256[](market.options.length);
        
        for (uint256 i = 0; i < market.options.length; i++) {
            userBets[i] = market.userBets[_user][i];
        }
        
        return userBets;
    }
    
    /**
     * @dev Withdraw platform fees (only owner)
     */
    function withdrawPlatformFees() external onlyOwner {
        require(totalPlatformFees > 0, "No fees to withdraw");
        
        uint256 amount = totalPlatformFees;
        totalPlatformFees = 0;
        
        payable(owner).transfer(amount);
        emit PlatformFeesWithdrawn(owner, amount);
    }
    
    /**
     * @dev Get the total number of markets created
     */
    function getTotalMarkets() external view returns (uint256) {
        return marketCounter;
    }
    
    /**
     * @dev Emergency function to transfer ownership
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }
}
