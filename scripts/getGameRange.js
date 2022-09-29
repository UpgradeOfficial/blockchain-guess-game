// npx hardhat run scripts/getGameRange.js --network localhost
const { ethers } = require("hardhat");

async function getGameRange() {
  const guess_game = await ethers.getContract("GuessGame");
  const game_range = await guess_game.getGuessRange();
  console.log(`The range the game is between 0 and ${game_range}!`);
}

getGameRange()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
