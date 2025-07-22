// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IRUSDDataHub {
    function getAdmin() external view returns (address);
    function getMinter() external view returns (address);
    function getRUSD() external view returns (address);
    function getOmnichainAdapter() external view returns (address);

    function pause() external;
    function unpause() external;

    function setAdmin(address _admin) external;
    function setMinter(address _minter) external;
    function setRUSD(address _rusd) external;
    function setOmnichainAdapter(address _omnichainAdapter) external;

    event AdminChanged(address admin);

    error InvalidChainIdForYUSD();
    error AlreadySet();
}

interface IRUSDDataHubMainChain is IRUSDDataHub {
    function setYUSD(address _yusd) external;
    function getYUSD() external view returns (address);
}
