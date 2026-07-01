// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

abstract contract SPProxyRegistry {
    function _knownSPProxies(uint256 chainId) internal pure returns (address[] memory proxies) {
        if (chainId == 1) {
            return _addresses2(0x3D8E699Db14d7781557fE94ad99d93Be180A6594, 0x996a99676d286fCeFCc1920369548c62ff7d6D11);
        }
        if (chainId == 10) return _addresses1(0x945C44803E92a3495C32be951052a62E45A5D964);
        if (chainId == 56) return _addresses1(0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63);
        if (chainId == 100) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 137) {
            return _addresses2(0x72efA4093539A909C1f9bcCA1aE6bcDa435a3433, 0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63);
        }
        if (chainId == 195) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 196) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 204) {
            return _addresses3(
                0x03688D459F172B058d39241456Ae213FC4E26941,
                0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD,
                0x91eEC742c970eF28CE307B53f0b6A7704D63b209
            );
        }
        if (chainId == 2741) return _addresses1(0x70140Bd1ec8019efA74C8795D555D5FFef60fb12);
        if (chainId == 5611) {
            return _addresses3(
                0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD,
                0x72efA4093539A909C1f9bcCA1aE6bcDa435a3433,
                0x759ac3CA33FeeAfB8C41aEbC8687A7Bd849Fc87a
            );
        }
        if (chainId == 7000) {
            proxies = new address[](7);
            proxies[0] = 0x1BC26dd23b773806f080Acf65Cfb744166be9463;
            proxies[1] = 0x30243E2C304070B22Ed66ab54A08fb0f5ca56382;
            proxies[2] = 0x3885E8F809Cb190C703779D90e0347F14866B03A;
            proxies[3] = 0x88f861053345d52f3B4168F7852Dd9Ff2E1BC62c;
            proxies[4] = 0xBbc279ee396074aC968b459d542DEE60c6bD71C1;
            proxies[5] = 0xD440572f5A242d62E512c4FE23c463878CFd5a64;
            proxies[6] = 0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63;
            return proxies;
        }
        if (chainId == 7001) {
            return _addresses3(
                0x00aFD4466E4Afa4F43cCd414b1BC65e574ACA2f5,
                0x29Dd65cb8654aE596d04bdf73Dd8995AAe4934b7,
                0x5d4D4eEd224028C230aFEbB69d279DE99bC06338
            );
        }
        if (chainId == 7560) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 8453) return _addresses1(0x2b3224D080452276a76690341e5Cfa81A945a985);
        if (chainId == 10_143) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 10_200) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 42_161) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 42_220) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 44_787) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 80_001) {
            proxies = new address[](4);
            proxies[0] = 0x4665fffdD8b48aDF5bab3621F835C831f0ee36D7;
            proxies[1] = 0x933D37fA836823A101AF23A8B2A0F07C7079b20F;
            proxies[2] = 0xBd770416a3345F91E4B34576cb804a576fa48EB1;
            proxies[3] = 0xEadFcE1eA8c2BB0DE3Cc3854076E1900373Aae59;
            return proxies;
        }
        if (chainId == 80_002) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 80_084) return _addresses1(0x2906d67A0929e1E6C9102AA4d97e1f1F9B112153);
        if (chainId == 80_085) return _addresses1(0x2774d96a841E522549CE7ADd3825fC31075384Cf);
        if (chainId == 84_532) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 98_865) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 421_614) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 534_351) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 534_352) return _addresses1(0xFBF614E89Ac79d738BaeF81CE6929897594b7E69);
        if (chainId == 11_155_111) return _addresses1(0x878c92FD89d8E0B93Dc0a3c907A2adc7577e39c5);
        if (chainId == 11_155_420) {
            return _addresses2(0x2b3224D080452276a76690341e5Cfa81A945a985, 0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        }
        if (chainId == 161_221_135) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        if (chainId == 666_666_666) return _addresses1(0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD);
        return new address[](0);
    }

    function _addresses1(address a0) private pure returns (address[] memory proxies) {
        proxies = new address[](1);
        proxies[0] = a0;
    }

    function _addresses2(address a0, address a1) private pure returns (address[] memory proxies) {
        proxies = new address[](2);
        proxies[0] = a0;
        proxies[1] = a1;
    }

    function _addresses3(address a0, address a1, address a2) private pure returns (address[] memory proxies) {
        proxies = new address[](3);
        proxies[0] = a0;
        proxies[1] = a1;
        proxies[2] = a2;
    }
}
