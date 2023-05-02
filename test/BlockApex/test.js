const { expect } = require("chai");
const { network, waffle, ethers } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;
const Web3 = require("web3");
const { defaultAbiCoder, hexlify, keccak256, toUtf8Bytes, solidityPack, parseUnits, AbiCoder, parseEther } = require("ethers/lib/utils");
const { Console, count } = require("console");
const { BigNumberish, Signer, constants } = require("ethers");
const { SignerWithAddress } = require("@nomiclabs/hardhat-ethers/signers");
var Eth = require('web3-eth');
var RLP = require("rlp");
var { BigNumber } = require('bignumber.js')
var bn = require('bignumber.js');
const { connect } = require("http2");
const hre = require("hardhat");
const { ecsign } = require("ethereumjs-util");
const assert = require("assert");
const { Contract, ContractFactory } = require("@ethersproject/contracts");
const { AbiItem } = require("web3-utils");
let abiCoder = new AbiCoder();
var web3 = new Web3(provider);

describe("Game Begins", async function () {

    async function advanceBlock() {
        return ethers.provider.send("evm_mine", [])
    }
    async function advanceBlockTo(blockNumber) {
        for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
            await advanceBlock()
        }
    }


    const [admin, User1, User2, User3, User4, User5] = provider.getWallets();

    let fuzz;

    beforeEach("Preparing Fuzz Contract", async function () {


        let Fuzz = await ethers.getContractFactory("testUnipiot");
        fuzz = await Fuzz.deploy();
        await fuzz.deployed();

    });

    it("update reward type ", async function () {
        console.log(fuzz);

    });

});
