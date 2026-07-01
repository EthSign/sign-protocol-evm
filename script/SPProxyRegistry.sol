// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

abstract contract SPProxyRegistry {
    // Source of truth: https://docs.sign.global/for-builders/address-book
    // Deprecated, struck-through address-book entries are intentionally omitted from batch upgrades.
    function _knownSPProxies(uint256 chainId) internal pure returns (address[] memory proxies) {
        if (chainId == 1) return _addresses1(0x3D8E699Db14d7781557fE94ad99d93Be180A6594);
        if (chainId == 10) return _addresses1(0x945C44803E92a3495C32be951052a62E45A5D964);
        if (chainId == 56) return _addresses1(0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63);
        if (chainId == 100) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 137) return _addresses1(0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63);
        if (chainId == 196) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 204) return _addresses1(0x03688D459F172B058d39241456Ae213FC4E26941);
        if (chainId == 5611) return _addresses1(0x72efA4093539A909C1f9bcCA1aE6bcDa435a3433);
        if (chainId == 7000) return _addresses1(0xBbc279ee396074aC968b459d542DEE60c6bD71C1);
        if (chainId == 7560) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 8453) return _addresses1(0x2b3224D080452276a76690341e5Cfa81A945a985);
        if (chainId == 10_200) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 42_161) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 42_220) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 44_787) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 80_001) return _addresses1(0x4665fffdD8b48aDF5bab3621F835C831f0ee36D7);
        if (chainId == 80_002) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 80_085) return _addresses1(0x2774d96a841E522549CE7ADd3825fC31075384Cf);
        if (chainId == 84_532) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 98_865) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 421_614) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 534_351) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 534_352) return _addresses1(0xFBF614E89Ac79d738BaeF81CE6929897594b7E69);
        if (chainId == 11_155_111) return _addresses1(0x878c92FD89d8E0B93Dc0a3c907A2adc7577e39c5);
        if (chainId == 11_155_420) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 666_666_666) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        return new address[](0);
    }

    function _addresses1(address a0) private pure returns (address[] memory proxies) {
        proxies = new address[](1);
        proxies[0] = a0;
    }
}
