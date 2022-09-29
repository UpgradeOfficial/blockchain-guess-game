// npx hardhat getGameRange --contract 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
task("getGameRange", "Get the range of number where you can guess from")
  .addParam("contract", "The address of the VRF contract that you want to read")
  .setAction(async (taskArgs) => {
    const contractAddr = taskArgs.contract
    const networkId = network.name
    console.log("Taking a guess on the", contractAddr, " on network ", networkId)
    const guess_game_contract = await ethers.getContractFactory("GuessGame")

    //Get signer information
    const accounts = await hre.ethers.getSigners()
    const signer = accounts[0]

    //Create connection to API Consumer Contract and call the createRequestTo function
    const guess_game = new ethers.Contract(
      contractAddr,
      guess_game_contract.interface,
      signer
    )

    try {
      const game_range = await guess_game.getGuessRange()
     
      console.log(
        `You guess should be between: 0 to ${game_range.toString()} `
      )
    } catch (error) {
        console.log(error)
      if (["hardhat", "localhost", "ganache"].includes(network.name)) {
        console.log("You'll have to manually update the value since you're on a local chain!")
      } else {
        console.log(
          `Visit https://vrf.chain.link/goerli/${process.env.VRF_SUBSCRIPTION_ID} and make sure that your last request fulfillment is there`
        )
      }
    }
  })

module.exports = {}
