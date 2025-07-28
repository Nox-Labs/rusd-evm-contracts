// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {CREATE3Factory} from "@layerzerolabs/create3-factory/contracts/CREATE3Factory.sol";

library Create3Deployer {
    function create3Deploy(
        address _create3Factory,
        bytes memory _creationCode,
        bytes memory _params,
        string memory _forSalt
    ) internal returns (address addr) {
        bytes32 salt = keccak256(abi.encodePacked(_forSalt));
        bytes memory creationCode = abi.encodePacked(_creationCode, _params);

        addr = CREATE3Factory(_create3Factory).deploy(salt, creationCode);
    }

    function _deploy_create3Factory(string memory _forSalt)
        internal
        returns (address create3Factory)
    {
        bytes memory creationCode = type(CREATE3Factory).creationCode;

        bytes32 salt = keccak256(abi.encodePacked(_forSalt));

        assembly {
            create3Factory := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }

        require(create3Factory != address(0), "CREATE3Factory deployment failed");
    }
}
