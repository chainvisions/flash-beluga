const { expect } = require('chai')
const hre, { ethers} = require('hardhat')

describe("Flash Beluga Wrapper Contract", () => {
    let [signer1, signer2, signer3]
    let beluga
    let storage
    let wrapper

    beforeEach(async () => {
        // Fetch signers.
        signer1, signer2, signer3 = await ethers.getSigners()
        // Deploy Mock BELUGA token.
        const tokenContract = await ethers.getContractFactory("MockERC20")
        beluga = await tokenContract.deploy("BelugaToken", "BELUGA")
        await beluga.deployed()
        // Deploy Storage contract.
        const storageContract = await ethers.getContractFactory("Storage")
        storage = await storageContract.deploy()
        await storage.deployed()
        // Deploy wrapper contract.
        const wrapperContract = await ethers.getContractFactory("Wrapper")
        wrapper = await wrapperContract.deploy(storage.address, beluga.address, 1)
        await wrapper.deployed()
    })

    it("Should allow for tokens to be wrapped", async () => {

    })

    it("Should allow for tokens to be unwrapped", async () => {

    })

    it("Should allow for flashloans to function", async () => {

    })

    it("Should generate profits on flashloan", async () => {
        
    })
})