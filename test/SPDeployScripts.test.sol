// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { SP } from "../src/core/SP.sol";
import { SPDeployBase } from "../script/SPDeployBase.sol";
import { UpgradeSPProxies } from "../script/UpgradeSPProxies.s.sol";

error ProdOwnerRequired(uint256 chainId);
error ProxyAlreadyUsesImplementation(address proxy, address implementation);
error ProxyImplementationMismatch(address proxy, address expected, address actual);
error ProxyVersionMismatch(address proxy, string expected, string actual);
error ProxyVersionUnreadable(address target);

contract SPDeployScriptsTest is Test {
    address internal deployer = address(0x1234);
    address internal prodOwner = address(0x5678);

    function test_checkChainAndSetOwner_transfersToProdOwnerWhenProdOwnerSetOnUnlistedChain() public {
        SPDeployBaseHarness harness = new SPDeployBaseHarness();
        MockOwnableProxy proxy = new MockOwnableProxy(deployer);
        uint256[] memory mainnetChainIds;

        vm.chainId(99_999);
        harness.configure(deployer, prodOwner, mainnetChainIds);
        harness.checkChainAndSetOwner(address(proxy));

        assertEq(proxy.owner(), prodOwner);
    }

    function test_checkChainAndSetOwner_revertsWhenMainnetChainHasNoProdOwner() public {
        SPDeployBaseHarness harness = new SPDeployBaseHarness();
        MockOwnableProxy proxy = new MockOwnableProxy(deployer);
        uint256[] memory mainnetChainIds = new uint256[](1);
        mainnetChainIds[0] = 1;

        vm.chainId(1);
        harness.configure(deployer, address(0), mainnetChainIds);
        vm.expectRevert(abi.encodeWithSelector(ProdOwnerRequired.selector, 1));
        harness.checkChainAndSetOwner(address(proxy));
    }

    function test_upgradeProxy_revertsNoopUpgradeWithoutCallData() public {
        UpgradeSPProxiesHarness harness = new UpgradeSPProxiesHarness();
        SP implementation = new SP();
        address proxy = harness.deployProxy(address(implementation));

        vm.expectRevert(abi.encodeWithSelector(ProxyAlreadyUsesImplementation.selector, proxy, address(implementation)));
        harness.upgradeProxy(proxy, address(implementation), "");
    }

    function test_upgradeProxy_revertsWhenPostUpgradeVersionIsUnexpected() public {
        UpgradeSPProxiesHarness harness = new UpgradeSPProxiesHarness();
        SP implementation = new SP();
        address proxy = harness.deployProxy(address(implementation));
        MockOldSP oldImplementation = new MockOldSP();

        harness.setExpectedVersionOverride("1.1.4");
        vm.expectRevert(abi.encodeWithSelector(ProxyVersionMismatch.selector, proxy, "1.1.4", "1.1.3"));
        harness.upgradeProxy(proxy, address(oldImplementation), "");
    }

    function test_upgradeProxy_defaultsExpectedVersionToImplementationVersion() public {
        UpgradeSPProxiesHarness harness = new UpgradeSPProxiesHarness();
        SP implementation = new SP();
        address proxy = harness.deployProxy(address(implementation));
        MockFutureSP futureImplementation = new MockFutureSP();

        harness.upgradeProxy(proxy, address(futureImplementation), "");

        assertEq(MockFutureSP(proxy).version(), "1.1.5");
    }

    function test_upgradeProxy_revertsWhenImplementationVersionIsUnreadable() public {
        UpgradeSPProxiesHarness harness = new UpgradeSPProxiesHarness();
        SP implementation = new SP();
        address proxy = harness.deployProxy(address(implementation));
        MockNoVersionSP noVersionImplementation = new MockNoVersionSP();

        vm.expectRevert(abi.encodeWithSelector(ProxyVersionUnreadable.selector, address(noVersionImplementation)));
        harness.upgradeProxy(proxy, address(noVersionImplementation), "");
    }

    function test_upgradeProxy_revertsWhenImplementationSlotDoesNotChange() public {
        UpgradeSPProxiesHarness harness = new UpgradeSPProxiesHarness();
        MockNoopUpgradeProxy proxy = new MockNoopUpgradeProxy();
        SP implementation = new SP();

        vm.expectRevert(
            abi.encodeWithSelector(
                ProxyImplementationMismatch.selector, address(proxy), address(implementation), address(0)
            )
        );
        harness.upgradeProxy(address(proxy), address(implementation), "");
    }
}

contract SPDeployBaseHarness is SPDeployBase {
    function configure(address deployer_, address prodOwner_, uint256[] memory mainnetChainIds) external {
        _deployer = deployer_;
        _PROD_OWNER = prodOwner_;
        _MAINNET_CHAIN_IDS = mainnetChainIds;
    }

    function checkChainAndSetOwner(address proxy) external {
        _checkChainAndSetOwner(proxy);
    }
}

contract UpgradeSPProxiesHarness is UpgradeSPProxies {
    bool internal _hasExpectedVersionOverride;
    string internal _expectedVersionOverride;

    function setExpectedVersionOverride(string memory expectedVersion) external {
        _hasExpectedVersionOverride = true;
        _expectedVersionOverride = expectedVersion;
    }

    function deployProxy(address implementation) external returns (address) {
        bytes memory initData = abi.encodeCall(SP.initialize, (uint64(1), uint64(1)));
        return address(new ERC1967Proxy(implementation, initData));
    }

    function upgradeProxy(address proxy, address implementation, bytes memory upgradeCallData) external {
        _upgradeProxy(proxy, implementation, upgradeCallData);
    }

    function _expectedVersion(address implementation) internal view override returns (string memory) {
        if (_hasExpectedVersionOverride) return _expectedVersionOverride;
        return _readVersionOrRevert(implementation);
    }
}

contract MockOwnableProxy {
    address public owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function transferOwnership(address newOwner) external {
        owner = newOwner;
    }
}

contract MockOldSP is UUPSUpgradeable, OwnableUpgradeable {
    function version() external pure returns (string memory) {
        return "1.1.3";
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}

contract MockFutureSP is UUPSUpgradeable, OwnableUpgradeable {
    function version() external pure returns (string memory) {
        return "1.1.5";
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}

contract MockNoVersionSP is UUPSUpgradeable, OwnableUpgradeable {
    function _authorizeUpgrade(address) internal override onlyOwner { }
}

contract MockNoopUpgradeProxy {
    function upgradeToAndCall(address, bytes calldata) external payable { }

    function version() external pure returns (string memory) {
        return "1.1.4";
    }
}
