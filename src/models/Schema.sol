// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISPResolver} from "../interfaces/ISPResolver.sol";
import {DataLocation} from "./OffchainResource.sol";

struct Schema {
    bool revocable;
    DataLocation dataLocation;
    uint64 maxValidFor;
    ISPResolver resolver;
    string schema;
}
