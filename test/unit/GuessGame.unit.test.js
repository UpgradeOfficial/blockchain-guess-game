const { expect, assert } = require("chai");
const {
  ethers,
  deployments,
  getNamedAccounts,
  network,
} = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const { keccak256, AbiCoder, defaultAbiCoder } = require("ethers/lib/utils");
// change all the i_ and s_ to a get function

// this will only run on development
!developmentChains.includes(network.name)
  ? describe.skip
  : describe("GuessGame", function () {
      let deployer;
      let guess_game;
      let vrfCoordinatorV2Mock;

      beforeEach(async function () {
        // deploy using hardhat-deploy
        deployer = (await getNamedAccounts()).deployer;
        await deployments.fixture(["all"]);
        guess_game = await ethers.getContract("GuessGame", deployer);
        vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
      });

      describe("getBalance", async function () {
        it("Returns the balance of the address", async function () {
          const response = await guess_game.getBalance();
          assert.equal(response, 0);
        });
      });
      
      describe("Game Range", async function () {
        it("set the game range with by the owner", async function () {
          await guess_game.setGuessRange(100);
          const response = await guess_game.getGuessRange();
          assert.equal(response, 100);
        });
        it("set the game range with by the player", async function () {
          accounts = await ethers.getSigners()
          player = accounts[3]
          const player_guess_game = guess_game.connect(player)
          const gamerange = await player_guess_game.getGuessRange();
          assert.equal(gamerange, 256)
          await expect(
            player_guess_game.setGuessRange(100)
          ).to.be.revertedWith("Game__OnlyOwner");
          
        });
      });
      describe("getRecentWinner", async function () {
        it("Returns the recent winner", async function () {
          const response = await guess_game.getRecentWinner();
          assert.equal(response, 0);
        });
      });
      describe("Reset", async function () {
        // it("set all the variables to their default state", async function () {
        //   await guess_game.reset();
        // });
        it("set all the variables to their default state by random player", async function () {
          accounts = await ethers.getSigners()
          player = accounts[3]
          const player_guess_game = guess_game.connect(player)
          await expect(
            player_guess_game.reset()
          ).to.be.revertedWith("Game__OnlyOwner");
          
        });
      });
      describe("hackableGuess", async function () {
        it("Guess the number from the contract without paying the minimum fee", async function () {
          await expect(
            guess_game.hackableGuess(45)
          ).to.be.revertedWith("GuessGame__FundNotPaid");
        });

        it("Guess the number from the contract with wrong value", async function () {
          await guess_game.hackableGuess(45, { value: 3 });
          const response = await guess_game.getLengthOfWinners();
          const game_state = await guess_game.getGameState();
          assert.equal(game_state, "0");
          assert.equal(response.toNumber(), 0);
        });
        it("emit an event in the hackable contract", async function () {
          await expect(guess_game.hackableGuess(45, { value: 3 })).to.emit(
            guess_game,
            "Log"
          );
        });
        it("emit an event in message", async function () {
          const txResponse = await guess_game.hackableGuess(45, { value: 3 }); // emits requestId
          const txReceipt = await txResponse.wait(1); // waits 1 block
          const log = txReceipt.events[0].args;
          assert.equal(log.message, "sorry you guessed wrong");
          assert.equal(log.sender, deployer);
          const game_state = await guess_game.getGameState();
          assert.equal(game_state, "0");
        });

        // it("Guess the number from the correct result", async function() {
         
        // });
      });
      describe("unhackableGuess", async function () {
        it("Should successfully request a random number", async () => {
          await expect(guess_game.unhackableGuess(45, { value: 3 })).to.emit(
            vrfCoordinatorV2Mock,
            "RandomWordsRequested"
          );
        });

        it("Should successfully request a random number and get a result", async () => {
          await guess_game.unhackableGuess(45, { value: 3 });
          const guess = await guess_game.getRecentGuess();
          assert.equal(guess.toString(), 0);
          const requestId = await guess_game.s_requestId();
        });


      });

      describe("fulfillRandomWords", () => {
        it("GUESSGAME after random number is returned", async function () {
            await new Promise(async (resolve, reject) => {
                guess_game.once("Log", async () => {
                    try {
                        const playerlength = await guess_game.getLengthOfWinners()
                        const guess_game_answer = await guess_game.getLatestAnswer()
                        const guess_game_guess = await guess_game.getRecentGuess()
                        console.log("guess_game_answer: ", guess_game_answer)
                        assert.equal(playerlength, 0)
                        assert.equal(guess_game_guess, 45)
                        resolve()
                    } catch (e) {
                        console.log(e)
                        reject(e)
                    }
                })
                try {
                    const fee = await guess_game.getEntranceFee()
                    const requestGuessGameResponse = await guess_game.unhackableGuess(45,{
                        value: fee.toString(),
                    })
                    const requestGuessGameReceipt = await requestGuessGameResponse.wait(1)
                    await vrfCoordinatorV2Mock.fulfillRandomWords(
                        requestGuessGameReceipt.events[1].args.requestId,
                        guess_game.address
                    )
                } catch (e) {
                    console.log(e)
                    reject(e)
                }
            })
        })
    })
    });
