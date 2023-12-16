// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISAPResolver} from "../interfaces/ISAPResolver.sol";

struct Schema {
    bool revocable;
    uint64 maxValidFor;
    ISAPResolver resolver;
    string schema;
}
