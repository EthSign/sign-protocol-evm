// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISP} from "../interfaces/ISP.sol";
import {ISPResolver} from "../interfaces/ISPResolver.sol";
import {Schema} from "../models/Schema.sol";
import {Attestation, OffchainAttestation} from "../models/Attestation.sol";
import {SchemaMetadata} from "../models/OffchainResource.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SP is ISP, UUPSUpgradeable, OwnableUpgradeable {
    /// @custom:storage-location erc7201:ethsign.SP
    struct SPStorage {
        mapping(uint256 => Schema) _schemaRegistry;
        mapping(uint256 => Attestation) _attestationRegistry;
        mapping(string => OffchainAttestation) _offchainAttestationRegistry;
        uint256 schemaCounter;
        uint256 attestationCounter;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.SP")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SPStorageLocation = 0x9f5ee6fb062129ebe4f4f93ab4866ee289599fbb940712219d796d503e3bd400;

    function _getSPStorage() internal pure returns (SPStorage storage $) {
        assembly {
            $.slot := SPStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        if (block.chainid != 31337) {
            _disableInitializers();
        }
    }

    function initialize() external initializer {
        SPStorage storage $ = _getSPStorage();
        __Ownable_init(_msgSender());
        $.schemaCounter = 1;
        $.attestationCounter = 1;
    }

    function register(SchemaMetadata calldata uri, Schema calldata schema)
        external
        override
        returns (uint256 schemaId)
    {
        return _register(uri, schema);
    }

    function registerBatch(SchemaMetadata[] calldata uris, Schema[] calldata schemas)
        external
        override
        returns (uint256[] memory schemaIds)
    {
        schemaIds = new uint256[](schemas.length);
        for (uint256 i = 0; i < schemas.length; i++) {
            schemaIds[i] = _register(uris[i], schemas[i]);
        }
    }

    function attest(Attestation calldata attestation) external override returns (uint256) {
        (uint256 schemaId, uint256 attestationId) = _attest(attestation);
        ISPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) resolver.didReceiveAttestation(_msgSender(), schemaId, attestationId);
        return attestationId;
    }

    function attestBatch(Attestation[] calldata attestations)
        external
        override
        returns (uint256[] memory attestationIds)
    {
        attestationIds = new uint256[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            (uint256 schemaId, uint256 attestationId) = _attest(attestations[i]);
            attestationIds[i] = attestationId;
            ISPResolver resolver = __getResolverFromAttestationId(attestationId);
            if (address(resolver) != address(0)) {
                resolver.didReceiveAttestation(_msgSender(), schemaId, attestationId);
            }
        }
    }

    function attest(Attestation calldata attestation, uint256 resolverFeesETH) external payable returns (uint256) {
        (uint256 schemaId, uint256 attestationId) = _attest(attestation);
        ISPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveAttestation{value: resolverFeesETH}(_msgSender(), schemaId, attestationId);
        }
        return attestationId;
    }

    function attestBatch(Attestation[] calldata attestations, uint256[] calldata resolverFeesETH)
        external
        payable
        override
        returns (uint256[] memory attestationIds)
    {
        attestationIds = new uint256[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            (uint256 schemaId, uint256 attestationId) = _attest(attestations[i]);
            attestationIds[i] = attestationId;
            ISPResolver resolver = __getResolverFromAttestationId(attestationId);
            if (address(resolver) != address(0)) {
                resolver.didReceiveAttestation{value: resolverFeesETH[i]}(_msgSender(), schemaId, attestationId);
            }
        }
    }

    function attest(Attestation calldata attestation, IERC20 resolverFeesERC20Token, uint256 resolverFeesERC20Amount)
        external
        override
        returns (uint256)
    {
        (uint256 schemaId, uint256 attestationId) = _attest(attestation);
        ISPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveAttestation(
                _msgSender(), schemaId, attestationId, resolverFeesERC20Token, resolverFeesERC20Amount
            );
        }
        return attestationId;
    }

    function attestBatch(
        Attestation[] calldata attestations,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override returns (uint256[] memory attestationIds) {
        attestationIds = new uint256[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            (uint256 schemaId, uint256 attestationId) = _attest(attestations[i]);
            attestationIds[i] = attestationId;
            ISPResolver resolver = __getResolverFromAttestationId(attestationId);
            if (address(resolver) != address(0)) {
                resolver.didReceiveAttestation(
                    _msgSender(), schemaId, attestationId, resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
                );
            }
        }
    }

    function attestOffchain(string calldata attestationId) external override {
        _attestOffchain(attestationId);
    }

    function attestOffchainBatch(string[] calldata attestationIds) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attestOffchain(attestationIds[i]);
        }
    }

    function revoke(uint256 attestationId, string calldata reason) external override {
        uint256 schemaId = _revoke(attestationId, reason);
        ISPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveRevocation(_msgSender(), schemaId, attestationId);
        }
    }

    function revokeBatch(uint256[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            uint256 schemaId = _revoke(attestationIds[i], reasons[i]);
            ISPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveRevocation(_msgSender(), schemaId, attestationIds[i]);
            }
        }
    }

    function revoke(uint256 attestationId, string calldata reason, uint256 resolverFeesETH) external payable override {
        uint256 schemaId = _revoke(attestationId, reason);
        ISPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveRevocation{value: resolverFeesETH}(_msgSender(), schemaId, attestationId);
        }
    }

    function revokeBatch(
        uint256[] calldata attestationIds,
        string[] calldata reasons,
        uint256[] calldata resolverFeesETH
    ) external payable override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            uint256 schemaId = _revoke(attestationIds[i], reasons[i]);
            ISPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveRevocation{value: resolverFeesETH[i]}(_msgSender(), schemaId, attestationIds[i]);
            }
        }
    }

    function revoke(
        uint256 attestationId,
        string calldata reason,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount
    ) external override {
        uint256 schemaId = _revoke(attestationId, reason);
        ISPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveRevocation(
                _msgSender(), schemaId, attestationId, resolverFeesERC20Token, resolverFeesERC20Amount
            );
        }
    }

    function revokeBatch(
        uint256[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            uint256 schemaId = _revoke(attestationIds[i], reasons[i]);
            ISPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveRevocation(
                    _msgSender(), schemaId, attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
                );
            }
        }
    }

    function revokeOffchain(string calldata attestationId, string calldata reason) external override {
        _revokeOffchain(attestationId, reason);
    }

    function revokeOffchainBatch(string[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revokeOffchain(attestationIds[i], reasons[i]);
        }
    }

    function getSchema(uint256 schemaId) external view override returns (Schema memory) {
        return _getSPStorage()._schemaRegistry[schemaId];
    }

    function getAttestation(uint256 attestationId) external view override returns (Attestation memory) {
        return _getSPStorage()._attestationRegistry[attestationId];
    }

    function getOffchainAttestation(string calldata attestationId) external view returns (OffchainAttestation memory) {
        return _getSPStorage()._offchainAttestationRegistry[attestationId];
    }

    function schemaCounter() external view override returns (uint256) {
        return _getSPStorage().schemaCounter;
    }

    function attestationCounter() external view override returns (uint256) {
        return _getSPStorage().attestationCounter;
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    function _register(SchemaMetadata calldata uri, Schema calldata schema) internal returns (uint256 schemaId) {
        SPStorage storage $ = _getSPStorage();
        schemaId = $.schemaCounter++;
        $._schemaRegistry[schemaId] = schema;
        emit SchemaRegistered(schemaId, uri.dataLocation, uri.uri);
    }

    function _attest(Attestation calldata attestation) internal returns (uint256 schemaId, uint256 attestationId) {
        SPStorage storage $ = _getSPStorage();
        attestationId = $.attestationCounter++;
        if (attestation.attester != _msgSender()) revert AttestationWrongAttester(attestation.attester, _msgSender());
        if (attestation.linkedAttestationId > 0 && !__attestationExists(attestation.linkedAttestationId)) {
            revert AttestationNonexistent(attestation.linkedAttestationId);
        }
        if (
            attestation.linkedAttestationId != 0
                && $._attestationRegistry[attestation.linkedAttestationId].attester != _msgSender()
        ) {
            revert AttestationWrongAttester(
                $._attestationRegistry[attestation.linkedAttestationId].attester, _msgSender()
            );
        }
        Schema memory s = $._schemaRegistry[attestation.schemaId];
        if (!__schemaExists(attestation.schemaId)) revert SchemaNonexistent(attestation.schemaId);
        if (s.maxValidFor > 0) {
            uint256 attestationValidFor = attestation.validUntil - block.timestamp;
            if (s.maxValidFor < attestationValidFor) {
                revert AttestationInvalidDuration(attestationId, s.maxValidFor, uint64(attestationValidFor));
            }
        }
        $._attestationRegistry[attestationId] = attestation;
        emit AttestationMade(attestationId);
        return (attestation.schemaId, attestationId);
    }

    function _attestOffchain(string calldata attestationId) internal {
        SPStorage storage $ = _getSPStorage();
        OffchainAttestation storage attestation = $._offchainAttestationRegistry[attestationId];
        if (__offchainAttestationExists(attestationId)) {
            revert OffchainAttestationExists(attestationId);
        }
        attestation.timestamp = uint64(block.timestamp);
        attestation.attester = _msgSender();
        emit OffchainAttestationMade(attestationId);
    }

    function _revoke(uint256 attestationId, string calldata reason) internal returns (uint256 schemaId) {
        SPStorage storage $ = _getSPStorage();
        Attestation storage a = $._attestationRegistry[attestationId];
        if (a.attester == address(0)) revert AttestationNonexistent(attestationId);
        if (a.attester != _msgSender()) revert AttestationWrongAttester(a.attester, _msgSender());
        Schema memory s = $._schemaRegistry[a.schemaId];
        if (!s.revocable) revert AttestationIrrevocable(a.schemaId, attestationId);
        if (a.revoked) revert AttestationAlreadyRevoked(attestationId);
        a.revoked = true;
        emit AttestationRevoked(attestationId, reason);
        return a.schemaId;
    }

    function _revokeOffchain(string calldata attestationId, string calldata reason) internal {
        SPStorage storage $ = _getSPStorage();
        OffchainAttestation storage attestation = $._offchainAttestationRegistry[attestationId];
        if (!__offchainAttestationExists(attestationId)) {
            revert OffchainAttestationNonexistent(attestationId);
        }
        if (attestation.attester != _msgSender()) {
            revert AttestationWrongAttester(attestation.attester, _msgSender());
        }
        if (attestation.timestamp == 1) {
            revert OffchainAttestationAlreadyRevoked(attestationId);
        }
        attestation.timestamp = 1;
        emit OffchainAttestationRevoked(attestationId, reason);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    function __getResolverFromAttestationId(uint256 attestationId) internal view returns (ISPResolver) {
        SPStorage storage $ = _getSPStorage();
        Attestation memory a = $._attestationRegistry[attestationId];
        Schema memory s = $._schemaRegistry[a.schemaId];
        return s.resolver;
    }

    function __schemaExists(uint256 schemaId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return schemaId < $.schemaCounter;
    }

    function __attestationExists(uint256 attestationId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return attestationId < $.attestationCounter;
    }

    function __offchainAttestationExists(string memory attestationId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return $._offchainAttestationRegistry[attestationId].timestamp != 0;
    }
}
