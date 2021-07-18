const { ethers } = require('hardhat')

const numberToWei = (number) => {
    return ethers.utils.parseUnits(number)
}

module.exports = { numberToWei }