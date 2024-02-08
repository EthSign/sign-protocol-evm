// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ISPHook } from "../interfaces/ISPHook.sol";
import { DataLocation } from "./DataLocation.sol";

/**
 * @title Schema
 * @author Jack Xu @ EthSign
 * @notice This struct represents an on-chain Schema that Attestations can conform to.
 *
 * `registrant`: The address that registered this schema.
 * `revocable`: Whether Attestations that adopt this Schema can be revoked.
 * `dataLocation`: Where `Schema.data` is stored. See `DataLocation.DataLocation`.
 * `maxValidFor`: The maximum number of seconds that an Attestation can remain valid. 0 means Attestations can be valid
 * forever. This is enforced through `Attestation.validUntil`.
 * `hook`: The `ISPHook` that is called at the end of every function. 0 means there is no hook set. See
 * `ISPHook`.
 * `timestamp`: When the schema was registered. This is automatically populated by `_register(...)`.
 * `data`: The raw schema that `Attestation.data` should follow. Since there is no way to enforce this, it is a `string`
 * for easy readability.
 */
struct Schema {
    address registrant;
    bool revocable;
    DataLocation dataLocation;
    uint64 maxValidFor;
    ISPHook hook;
    uint64 timestamp;
    string data;
}
