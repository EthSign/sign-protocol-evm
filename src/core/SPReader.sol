// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.20;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Attestation as SPAttestation } from "../models/Attestation.sol"; // Ignoring Offchain Attestations
import { Attestation as VeraxAttestation, IVerax } from "src/interfaces/IVerax.sol";
import { SP } from "src/core/SP.sol";

contract SPReader is OwnableUpgradeable {
    /// @custom:storage-location erc7201:ethsign.SPReader
    struct SPReaderStorage {
        SP signProtocol;
        IVerax veraxRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.SPReader")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SPReaderStorageLocation =
        0x82ea65dbd7b30e84b1db8304693baa92edebefa6829498cda2f2368355a52200;

    function _getSPReaderStorage() internal pure returns (SPReaderStorage storage $) {
        assembly {
            $.slot := SPReaderStorageLocation
        }
    }

    constructor() {
        if (block.chainid != 31_337) {
            _disableInitializers();
        }
    }

    function initialize(address spAddress, address veraxAddress) public initializer {
        SPReaderStorage storage $ = _getSPReaderStorage();
        __Ownable_init(_msgSender());
        $.signProtocol = SP(spAddress);
        $.veraxRegistry = IVerax(veraxAddress);
    }

    /**
     * @notice Updates the address of the Verax Registry
     */
    function updateVeraxAddress(address veraxAddress) external onlyOwner {
        SPReaderStorage storage $ = _getSPReaderStorage();
        $.veraxRegistry = IVerax(veraxAddress);
    }

    /**
     * @notice Updates the address of the Sign Protocol Contract
     */
    function updateSPAddress(address spAddress) external onlyOwner {
        SPReaderStorage storage $ = _getSPReaderStorage();
        $.signProtocol = SP(spAddress);
    }

    /**
     * @param id -- The unique id of the attestation (bytes32)
     * @return Sign Protocol Attestation
     */
    function getAttestationSP(bytes32 id) external view returns (SPAttestation memory) {
        SPReaderStorage storage $ = _getSPReaderStorage();

        uint256 spId = uint256(id); // Converting id bytes32 to spID uint256 for comparison

        // Checks if Attestation ID is in the range of SP
        if (spId <= type(uint64).max) {
            // Attestation ID is in range for Sign Protocol
            SPAttestation memory attestation = $.signProtocol.getAttestation(uint64(spId)); // uint256 spID -> uint64
            // Checks if attestation is empty
            if (attestation.attestTimestamp != 0) {
                return attestation;
            }
        }
        // Attestation ID is out of range for Sign Protocol or SP Attestation is Empty
        VeraxAttestation memory vAttestation = $.veraxRegistry.getAttestation(id);
        return _convertVeraxToSP(vAttestation);
    }

    /**
     * @param _id The unique id of the attestation (bytes32)
     * @return Verax Attestation
     */
    function getAttestationVerax(bytes32 id) external view returns (VeraxAttestation memory) {
        SPReaderStorage storage $ = _getSPReaderStorage();

        VeraxAttestation memory vAttestation = $.veraxRegistry.getAttestation(id);

        // Checks if the Verax Attestation Exists
        if (vAttestation.attestedDate != 0) {
            return vAttestation;
        } else {
            // Verax Attestation does not exist
            uint256 spId = uint256(id);

            // Checks if Attestation ID is in the range of SP
            if (spId <= type(uint64).max) {
                SPAttestation memory attestation = $.signProtocol.getAttestation(uint64(spId));
                // Checks If Attestation is Empty
                if (attestation.attestTimestamp != 0) {
                    return _convertSPToVerax(attestation, id);
                }
            }

            return vAttestation; // Returns the empty Verax Attestation
        }
    }

    /**
     * @notice Helper Function: Transforms a Verax Attestation to a Sign Protocol Attestation
     */
    function _convertVeraxToSP(VeraxAttestation memory _vAttestation)
        private
        pure
        returns (SPAttestation memory attestation)
    {
        if (uint256(_vAttestation.schemaId) <= type(uint64).max) {
            attestation.schemaId = uint64(uint256(_vAttestation.schemaId)); // bytes32 -> uint256 -> uint64
        } // Otherwise null

        attestation.attestTimestamp = _vAttestation.attestedDate;
        attestation.revokeTimestamp = _vAttestation.revocationDate;
        attestation.attester = _vAttestation.attester;
        attestation.validUntil = _vAttestation.expirationDate;
        attestation.revoked = _vAttestation.revoked;
        attestation.recipients = new bytes[](1);
        attestation.recipients[0] = _vAttestation.subject;
        attestation.data = _vAttestation.attestationData;

        // attestation.linkedAttestationId (I do not believe they have a comparable property - thus leaving as null)
        // attestation.dataLocation (I do not believe they have a comparable property - thus leaving as null)

        return attestation;
    }

    /**
     * @notice Helper Function: Transforms a Sign Protocol Attestation to a Verax Attestation
     */
    function _convertSPToVerax(
        SPAttestation memory _attestation,
        bytes32 id
    )
        private
        pure
        returns (VeraxAttestation memory vAttestation)
    {
        vAttestation.attestationId = id;
        vAttestation.schemaId = bytes32(uint256(_attestation.schemaId)); // uint64 -> uint256 -> bytes32
        vAttestation.attester = _attestation.attester;
        vAttestation.attestedDate = _attestation.attestTimestamp;
        vAttestation.expirationDate = _attestation.validUntil;
        vAttestation.revocationDate = _attestation.revokeTimestamp;
        vAttestation.revoked = _attestation.revoked;
        vAttestation.attestationData = _attestation.data;
        vAttestation.subject = _attestation.recipients[0];
        // Sign Protocol has a array while Verax only has one (I have decided to take the first)

        // vAttestation.replacedBy = 0; -- Does not exist in Sign Protocol
        // vAttestation.portal = 0; -- Does not exist in Sign Protocol
        // vAttestation.version = 0; -- Does not exist in Sign Protocol

        return vAttestation;
    }
}
