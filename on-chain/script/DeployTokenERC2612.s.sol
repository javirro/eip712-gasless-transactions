// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenERC2612}  from "../src/ERC2612/TokenERC2612.sol";

contract DeployTokenERC2612 is Script {
    TokenERC2612 public tokenERC2612  ;

    function run() public {
      uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        tokenERC2612 = new TokenERC2612("TokenERC2612", "T1-ERC2612", "1");
        console.log("TokenERC2612 deployed at:", address(tokenERC2612));
        vm.stopBroadcast();
    }
}
