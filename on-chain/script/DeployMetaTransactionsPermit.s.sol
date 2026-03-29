// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MetaRelayer}  from "../src/EIP712/MetaTransactionsWithPermit.sol";

contract MetaTransactionsScript is Script {
    MetaRelayer public metaRelayer;

    function run() public {
      uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        metaRelayer = new MetaRelayer("MetaRelayer", "1");
        console.log("MetaRelayer deployed at:", address(metaRelayer));
        vm.stopBroadcast();
    }
}
