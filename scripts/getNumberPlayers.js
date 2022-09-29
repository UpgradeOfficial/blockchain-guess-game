// npx hardhat run scripts/guessNumber.js --network localhost
const { ethers } = require("hardhat")

async function getNumberPlayers() {
    const guess_game = await ethers.getContract("GuessGame")
    const entranceFee = await guess_game.getEntranceFee()
    await guess_game.hackableGuess(1,{ value:  1 })
    console.log("Guessed !")
}


getNumberPlayers()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
