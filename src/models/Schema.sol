// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISAPResolver} from "../interfaces/ISAPResolver.sol";
import {DataLocation} from "./OffchainResource.sol";

struct Schema {
    bool revocable;
    DataLocation dataLocation;
    uint64 maxValidFor;
    ISAPResolver resolver;
    string schema;
}
