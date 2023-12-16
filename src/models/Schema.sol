// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct Schema {
    bool revocable;
    bool revertIfResolverFailed;
    uint64 maxValidFor;
    address resolver;
    string schema;
}
