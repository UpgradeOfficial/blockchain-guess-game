/*
GuessTheRandomNumber is a game where you win 1 Ether if you can guess the
pseudo random number generated from block hash and timestamp.

At first glance, it seems impossible to guess the correct number.
But let's see how easy it is win.

1. Alice deploys GuessTheRandomNumber with 1 Ether
2. Eve deploys Attack
3. Eve calls Attack.attack() and wins 1 Ether

What happened?
Attack computed the correct answer by simply copying the code that computes the random number.
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error GuessGame__FundNotPaid();
error Game__GameNotOpen();
error Game__OnlyOwner();

/**
 * @title The GuessGame contract
 * @notice A contract that gets random values from Chainlink VRF V2
 */
contract GuessGame is VRFConsumerBaseV2 {
    enum GameState {
        OPEN,
        CALCULATING
    }
    VRFCoordinatorV2Interface immutable COORDINATOR;
    event Log(address indexed sender, string message);

    // Your subscription ID.
    uint64 immutable s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 immutable s_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 constant CALLBACK_GAS_LIMIT = 100000;

    // The default is 3, but you can set this higher.
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 constant NUM_WORDS = 1;

    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    address payable[] s_players;
    address[] s_winners;
    address s_recentWinner;
    uint s_latestAnswer;
    uint s_recentGuess;
    address s_recentPlayer;
    uint s_entranceFee;
    GameState private s_gameState;
    uint s_guessRange;

    constructor(
        address vrfCoordinator,
        uint64 subscriptionId,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_owner = msg.sender;
        s_entranceFee = 1;
        s_guessRange = 256;
        s_subscriptionId = subscriptionId;
        s_gameState = GameState.OPEN;
    }

    modifier onlyOwner() {
        if (msg.sender != s_owner) {
            revert Game__OnlyOwner();
        }
        _;
    }

    function unhackableGuess(uint _guess) external payable {
        if (msg.value < s_entranceFee) {
            revert GuessGame__FundNotPaid();
        }
        s_gameState = GameState.CALCULATING;
        s_recentGuess = _guess;
        s_recentPlayer = msg.sender;
        // Will revert if subscription is not set and funded.
        
        s_requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        s_gameState = GameState.CALCULATING;
    }

    /**
     * @notice Callback function used by VRF Coordinator
     *
     * @param requestId - id of the request
     * @param randomWords - array of random results from VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        s_randomWords = randomWords;

        s_latestAnswer = s_randomWords[0] % s_guessRange;
        if (s_recentGuess == s_latestAnswer) {
            (bool sent, ) = s_recentPlayer.call{value: 1 ether}("");
            require(sent, "Failed to send Ether");
            s_winners.push(s_recentPlayer);
            s_recentWinner = s_recentPlayer;

            emit Log(s_recentPlayer, "You won");
        }
        s_gameState = GameState.OPEN;
        emit Log(s_recentPlayer, "sorry you guessed wrong");
    }

    function hackableGuess(uint _guess) public payable {
        if (s_gameState != GameState.OPEN) {
            revert Game__GameNotOpen();
        }
        if (msg.value < s_entranceFee) {
            revert GuessGame__FundNotPaid();
        }
        s_gameState = GameState.CALCULATING;
        uint answer = uint(
            keccak256(
                abi.encodePacked(blockhash(block.number - 2), block.timestamp)
            )
        );
        s_recentGuess = _guess;
        uint answer_mod = answer % s_guessRange;
        // console.log(
        // "answer: %s, guess: %s,", answer_mod, guess);
        s_latestAnswer = answer_mod;
        s_players.push(payable(msg.sender));
        if (_guess == answer_mod) {
            (bool sent, ) = msg.sender.call{value: 1 ether}("");
            require(sent, "Failed to send Ether");
            s_winners.push(msg.sender);
           
            s_recentWinner = msg.sender;

            emit Log(msg.sender, "You won");
        }
        s_gameState = GameState.OPEN;
        s_recentPlayer = msg.sender;
        emit Log(msg.sender, "sorry you guessed wrong");
        // console.log(
        // "guess: %s, answer_mod: %s, answer: %s", _guess, answer_mod, answer);
    }

    function getPlayers(uint _index) public view returns (address) {
        return s_players[_index];
    }
    function getWinners(uint _index) public view returns (address) {
        return s_winners[_index];
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfWinners() public view returns (uint) {
        return s_winners.length;
    }
    function getLengthOfPlayers() public view returns (uint) {
        return s_players.length;
    }

    function getRecentGuess() public view returns (uint) {
        return s_recentGuess;
    }

    function getRecentPlayer() public view returns (address) {
        return s_recentPlayer;
    }

    function getGameState() public view returns (GameState) {
        return s_gameState;
    }
    function setGameState(GameState _state) public onlyOwner {
        s_gameState = _state;
    }

    function getEntranceFee() public view returns (uint) {
        return s_entranceFee;
    }

    function setEntranceFee(uint _entranceFee) public onlyOwner {
        s_entranceFee = _entranceFee;
    }

    function getGuessRange() public view returns (uint) {
        return s_guessRange;
    }
    function getOwner() public view returns (address) {
        return s_owner;
    }
    function isOwner(address _player) public view returns (bool) {
        return s_owner == _player;
    }

    function setGuessRange(uint _guessRange) public onlyOwner {
        s_guessRange = _guessRange;
    }

    function getLatestAnswer() public view returns (uint256) {
        return s_latestAnswer;
    }

    function reset() public onlyOwner {
        s_players = new address payable[](0);
        s_winners = new address[](0);
        s_recentWinner = address(0);
        s_latestAnswer = 0;
        s_recentGuess = 0;
        s_recentPlayer = address(0);
        s_entranceFee = 3;
        s_gameState = GameState.OPEN;
        s_guessRange = 256; 
    }
}
