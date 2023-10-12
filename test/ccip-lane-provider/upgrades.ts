import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
var fs = require('fs');

describe("CCIP Lane Provider upgrade test", function () {

    it("is possible to ugprade deploy an upgradable version of the contract", async () => {
        // const accounts = await ethers.getSigners();

        const ERC20 = await ethers.getContractFactory("Token");
        const deployTx = await ERC20.getDeployTransaction("Test Coin", "TC");

        const deployTxObj = {
            to: "0x",
            value: "0x",
            data: deployTx.data
        };

        const mintTxObj = {
            
        }

        fs.writeFileSync('deploytxobj.json', JSON.stringify(deployTxObj));


        // const CCIPLaneProvider = await ethers.getContractFactory("CCIPLaneProvider");
        // const laneProvider = await upgrades.deployProxy(CCIPLaneProvider, [accounts[0].address], {
        //     kind: "uups"
        // });
        
        // console.log("laneProvider1", laneProvider);
        // const laneProviderProxy = await laneProvider.getAddress();
        
        // const laneProvider2 = await upgrades.upgradeProxy(laneProviderProxy, CCIPLaneProvider);
        // console.log("laneProvider2", laneProvider2);
    });

});
