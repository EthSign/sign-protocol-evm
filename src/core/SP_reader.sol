// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.20;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Attestation as SPAttestation } from "../models/Attestation.sol"; // Ignoring Offchain Attestations
import { Attestation as VeraxAttestation, IVerax } from "src/interfaces/IVerax.sol";
import { SP } from "src/core/SP.sol";
/*
    Found Information Above on Github:
    - Verax's Attestation struct 
    - Interface I created to call a certain function -- getAttestation()
*/

contract Reader is OwnableUpgradeable {
    /// @custom:storage-location erc7201:ethsign.SP-Reader
    struct ReaderStorage {
        SP signProtocol;
        IVerax veraxRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.SP-Reader")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReaderStorageLocation = 0xb209ab9212fdbbb86ea9ba187ed37f12ac1d5679ecdf9a605a02f993a67d7400;

    error Invalid();
    error Incompatible();
    error DoesNotExist();

    function _getReaderStorage() internal pure returns (ReaderStorage storage $) {
        assembly {
            $.slot := ReaderStorageLocation
        }
    }

    constructor() {
        if (block.chainid != 31_337) {
            _disableInitializers();
        }
    }

    function initialize(address _spAddress, address _veraxAddress) public initializer {
        ReaderStorage storage $ = _getReaderStorage();
        __Ownable_init(_msgSender());
        $.signProtocol = SP(_spAddress);
        $.veraxRegistry = IVerax(_veraxAddress);
    }

    /**
     * @notice Updates the address of the Verax Registry.
     * @dev Only the owner of the contract can call this function. Reverts if the provided address is the zero address.
     * @param _veraxAddress The new address of the Verax Registry.
     */
    function updateVeraxAddress(address _veraxAddress) external onlyOwner {
        ReaderStorage storage $ = _getReaderStorage();
        if (_veraxAddress == address(0)) revert Invalid();
        $.veraxRegistry = IVerax(_veraxAddress);
    }

    /**
     * @notice Updates the address of the Sign Protocol Contract.
     * @dev Only the owner of the contract can call this function. Reverts if the provided address is the zero address.
     * @param _spAddress The new address of the Sign Protocol Contract.
     */
    function updateSPAddress(address _spAddress) external onlyOwner {
        ReaderStorage storage $ = _getReaderStorage();
        if (_spAddress == address(0)) revert Invalid();
        $.signProtocol = SP(_spAddress);
    }

    /**
     * @param _id The unique id of the attestation. Takes a bytes32 as this is the datatype Verax uses
     * @return Sign Protocol Attestation
     */
    function getAttestationMethod1(bytes32 _id) external view returns (SPAttestation memory) {
        ReaderStorage storage $ = _getReaderStorage();

        uint256 spId = uint256(_id); // Converting bytes32 to uint256 for comparison

        if (spId > type(uint64).max) {
            // ID is out of range for Sign Protocol
            VeraxAttestation memory vAttestation = $.veraxRegistry.getAttestation(_id);
            return _convertVeraxToSP_nullID(vAttestation); // Attestation ID is out of range for Sign Protocol
        } else {
            // ID is in the range for Sign Protocol
            SPAttestation memory attestation = $.signProtocol.getAttestation(uint64(spId)); // uint256 spID -> uint64
            if (attestation.attestTimestamp != 0) {
                // Checks if attestation is empty
                return attestation;
            } else {
                // If SP Protocol Attestation does not exist
                VeraxAttestation memory vAttestation = $.veraxRegistry.getAttestation(_id);
                return _convertVeraxToSP(vAttestation, uint64(spId));
            }
        }
    }

    /**
     * @notice Helper Function: Transforms a Verax Attestation to a Sign Protocol Attestation
     * @param _vAttestation - The Verax Attestation
     * @param _id - AttestationId
     * @return Sign Protocol Attestation
     */
    function _convertVeraxToSP(
        VeraxAttestation memory _vAttestation,
        uint64 _id
    )
        private
        pure
        returns (SPAttestation memory)
    {
        SPAttestation memory attestation;

        if (uint256(_vAttestation.schemaId) > type(uint64).max) {
            attestation.schemaId = 0; // Leaving it null
        } else {
            attestation.schemaId = uint64(uint256(_vAttestation.schemaId)); // bytes32 -> uint256 -> uint64
        }

        attestation.linkedAttestationId = _id;
        attestation.attestTimestamp = _vAttestation.attestedDate;
        attestation.revokeTimestamp = _vAttestation.revocationDate;
        attestation.attester = _vAttestation.attester;
        attestation.validUntil = _vAttestation.expirationDate;
        attestation.revoked = _vAttestation.revoked;
        attestation.recipients = new bytes[](1);
        attestation.recipients[0] = _vAttestation.subject;
        attestation.data = _vAttestation.attestationData;
        // attestation.dataLocation (I do not believe they have a comparable property - thus leaving as null)

        return attestation;
    }

    /**
     * @notice Helper Function: Transforms a Verax Attestation to a Sign Protocol Attestation
     * @param _vAttestation - The Verax Attestation
     * @return Sign Protocol Attestation
     */
    function _convertVeraxToSP_nullID(VeraxAttestation memory _vAttestation)
        private
        pure
        returns (SPAttestation memory)
    {
        SPAttestation memory attestation;

        if (uint256(_vAttestation.schemaId) > type(uint64).max) {
            attestation.schemaId = 0; // Leaving it null
        } else {
            attestation.schemaId = uint64(uint256(_vAttestation.schemaId)); // bytes32 -> uint256 -> uint64
        }

        attestation.linkedAttestationId = 0; // Can create an arbitary number as the id is not in the uint64 range

        attestation.attestTimestamp = _vAttestation.attestedDate;
        attestation.revokeTimestamp = _vAttestation.revocationDate;
        attestation.attester = _vAttestation.attester;
        attestation.validUntil = _vAttestation.expirationDate;
        attestation.revoked = _vAttestation.revoked;
        attestation.recipients = new bytes[](1);
        attestation.recipients[0] = _vAttestation.subject;
        attestation.data = _vAttestation.attestationData;
        // attestation.dataLocation (I do not believe they have a comparable property - thus leaving as null)

        return attestation;
    }

    /**
     * @param _id The unique id of the attestation. Takes a bytes32 as this is the datatype Verax uses
     * @return Verax Attestation
     */
    function getAttestationMethod2(bytes32 _id) external view returns (VeraxAttestation memory) {
        ReaderStorage storage $ = _getReaderStorage();

        VeraxAttestation memory vAttestation = $.veraxRegistry.getAttestation(_id);

        // Checks if the Verax Attestation Exists
        if (vAttestation.attestedDate != 0) {
            return vAttestation;
        } else {
            uint256 spId = uint256(_id);

            if (spId < type(uint64).max) {
                SPAttestation memory attestation = $.signProtocol.getAttestation(uint64(spId));
                if (attestation.attestTimestamp != 0) {
                    return _convertSPToVerax(attestation);
                }
            }

            return vAttestation; // Returns the empty Verax Attestation
        }
    }

    /**
     * @notice Helper Function: Transforms a Sign Protocol Attestation to a Verax Attestation
     * @param _attestation - The Sign Protocol Attestation
     * @return Verax Attestation
     */
    function _convertSPToVerax(SPAttestation memory _attestation) private pure returns (VeraxAttestation memory) {
        VeraxAttestation memory vAttestation;

        vAttestation.attestationId = bytes32(uint256(_attestation.linkedAttestationId)); // uint64 -> uint256 -> bytes32
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
