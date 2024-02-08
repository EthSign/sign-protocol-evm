// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISPGlobalHook {
    function callHook(bytes calldata msgData, address msgSender) external;
}
