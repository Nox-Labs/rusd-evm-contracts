// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ChainsRegistry {
    mapping(uint256 => uint32) private _eids;

    mapping(uint256 => string) private _aliases;

    constructor() {
        _setChainEid();
        _setChainAliases();
    }

    function _setChainAliases() private {
        _aliases[42161] = "arbitrum";
        _aliases[137] = "polygon";
        _aliases[10] = "optimism";
        _aliases[8453] = "base";
        _aliases[43114] = "avalanche";
        _aliases[56] = "bsc";
        _aliases[5000] = "mantle";
        _aliases[1088] = "metis";
        _aliases[1329] = "sei";
        _aliases[31337] = "anvil";
        _aliases[11155111] = "sepolia";
        _aliases[103] = "solanadev";
        _aliases[101] = "solana";
    }

    function _setChainEid() private {
        _eids[42161] = 30110;
        _eids[137] = 30109;
        _eids[10] = 30111;
        _eids[8453] = 30184;
        _eids[43114] = 30106;
        _eids[56] = 30102;
        _eids[5000] = 30181;
        _eids[1088] = 30151;
        _eids[1329] = 30280;
        _eids[101] = 30168;
        // testnet
        _eids[11155111] = 40161;
        _eids[103] = 40168;
        // local
        _eids[31337] = 1;
    }

    error ChainIdNotFound(uint256 chainId);
    error ChainAliasNotFound(uint256 chainId);
    error EidNotFound(uint256 chainId);

    function getChainAlias(uint256 chainId) public view returns (string memory) {
        string memory _alias = _aliases[chainId];

        if (bytes(_alias).length == 0) revert ChainAliasNotFound(chainId);

        return _alias;
    }

    function getEid(uint256 chainId) public view returns (uint32) {
        uint32 eid = _eids[chainId];

        if (eid == 0) revert EidNotFound(chainId);

        return eid;
    }
}
