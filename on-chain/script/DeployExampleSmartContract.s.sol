// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ExampleSmartContract}  from "../src/EIP712/ExampleSmartContract.sol";

contract DeployExampleSmartContractScript is Script {
    ExampleSmartContract public exampleSmartContract;

    function run() public {
      uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        exampleSmartContract = new ExampleSmartContract();
        console.log("ExampleSmartContract deployed at:", address(exampleSmartContract));
        vm.stopBroadcast();
    }
}
