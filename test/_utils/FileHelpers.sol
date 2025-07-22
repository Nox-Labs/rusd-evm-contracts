// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {CommonBase} from "forge-std/Base.sol";
import {Constants} from "./Constants.sol";

struct AddressDataFromFile {
    address addr;
    string key; // key in the DEFAULT_PATH_TO_CONTRACTS json file (e.g. "MaatAddressProviderV1")
}

contract FileHelpers is Constants {
    string public constant DEFAULT_PATH_TO_CONTRACTS = "deployments/Contracts.json";

    string public pathToContracts = DEFAULT_PATH_TO_CONTRACTS;

    string public mainObjKey = "main key";

    Vm private vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function writeContractAddress(
        uint256 chainId,
        address contractAddress,
        string memory contractName
    ) public {
        string memory chainObjKey = string.concat(".", vm.toString(chainId));

        string memory json = _getOrCreateJsonFile();

        json = _writeChainIfNotExist(json, chainObjKey, chainId);

        _writeAddress(json, chainObjKey, contractName, contractAddress);
    }

    function readContractAddress(uint256 chainId, string memory contractName)
        public
        returns (address)
    {
        _checkFileExist();

        string memory chainObjKey = string.concat(".", vm.toString(chainId));

        string memory file = vm.readFile(pathToContracts);

        _checkChainExist(chainObjKey, file, chainId);

        _checkContractExist(chainObjKey, contractName, file, chainId);

        address contractAddress =
            vm.parseJsonAddress(file, string.concat(chainObjKey, ".", contractName));

        return contractAddress;
    }

    function readContractAddressNoRevert(uint256 chainId, string memory contractName)
        public
        returns (address)
    {
        try this.readContractAddress(chainId, contractName) returns (address contractAddress) {
            return contractAddress;
        } catch {
            return address(0);
        }
    }

    function readArrayOfAddresses(uint256 chainId, string memory prefix)
        public
        returns (AddressDataFromFile[] memory addresses)
    {
        _checkFileExist();

        string memory chainObjKey = string.concat(".", vm.toString(chainId));
        string memory file = vm.readFile(pathToContracts);

        _checkChainExist(chainObjKey, file, chainId);

        string[] memory keys = vm.parseJsonKeys(file, chainObjKey);
        uint256 addressesCount = 0;

        for (uint256 i = 0; i < keys.length; i++) {
            if (vm.indexOf(keys[i], prefix) != type(uint256).max) {
                addressesCount++;
            }
        }

        addresses = new AddressDataFromFile[](addressesCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < keys.length; i++) {
            if (vm.indexOf(keys[i], prefix) != type(uint256).max) {
                addresses[currentIndex] = AddressDataFromFile(
                    vm.parseJsonAddress(file, string.concat(chainObjKey, ".", keys[i])), keys[i]
                );
                currentIndex++;
            }
        }
    }

    /* ============== UTILS ============== */

    // receive: $pwd/deploy-targets/42161/strategies.json
    // returns: deploy-targets/42161/strategies.json
    function getLocalFilePath(string memory path) internal view returns (string memory name) {
        string[] memory data = vm.split(path, string.concat(vm.projectRoot(), Slash));
        name = data[1];
        name = vm.replace(name, "\\", Slash);
    }

    function getJsonFile(string memory path) public view returns (bytes memory data) {
        string memory json = vm.readFile(string.concat(path));
        data = vm.parseJson(json);
    }

    function startsWith(string memory str, string memory prefix) public view returns (bool) {
        return vm.indexOf(str, prefix) == 0;
    }

    /* ============== PRIVATE ============== */

    function _checkFileExist() private {
        bool isFileExist = vm.exists(pathToContracts);

        require(
            isFileExist,
            string.concat("File with path ", pathToContracts, " does not exist in project")
        );
    }

    function _checkChainExist(string memory chainObjKey, string memory json, uint256 chainId)
        internal
        view
    {
        bool isChainExist = vm.keyExistsJson(json, chainObjKey);

        require(
            isChainExist, string.concat("Chain ", vm.toString(chainId), " does not exist in file")
        );
    }

    function _checkContractExist(
        string memory chainObjKey,
        string memory contractName,
        string memory json,
        uint256 chainId
    ) private view {
        bool isContractExist = vm.keyExistsJson(json, string.concat(chainObjKey, ".", contractName));

        require(
            isContractExist,
            string.concat(
                "Contract ", contractName, " does not exist on chain ", vm.toString(chainId)
            )
        );
    }

    function _getOrCreateJsonFile() private returns (string memory) {
        bool isFileExist = vm.exists(pathToContracts);

        if (!isFileExist) vm.writeJson("{}", pathToContracts);

        string memory file = vm.readFile(pathToContracts);
        if (bytes(file).length == 0) vm.writeJson("{}", pathToContracts);

        file = vm.readFile(pathToContracts);
        string memory json = vm.serializeJson(mainObjKey, file);

        return json;
    }

    function _writeAddress(
        string memory json,
        string memory chainObjKey,
        string memory contractName,
        address contractAddress
    ) private {
        string memory chainObj;

        string[] memory keysOfChainObj = vm.parseJsonKeys(json, chainObjKey);

        for (uint256 i = 0; i < keysOfChainObj.length; i++) {
            address addressOfContract =
                vm.parseJsonAddress(json, string.concat(chainObjKey, ".", keysOfChainObj[i]));

            chainObj = vm.serializeAddress(chainObjKey, keysOfChainObj[i], addressOfContract);
        }

        chainObj = vm.serializeAddress(chainObjKey, contractName, contractAddress);

        vm.writeJson(chainObj, pathToContracts, chainObjKey);
    }

    function _writeChainIfNotExist(string memory json, string memory chainObjKey, uint256 chainId)
        private
        returns (string memory newJson)
    {
        bool isChainExist = vm.keyExistsJson(json, chainObjKey);

        if (isChainExist) return json;

        string memory mainObj = vm.serializeString(mainObjKey, vm.toString(chainId), "{}");

        vm.writeJson(mainObj, pathToContracts);

        newJson = _getOrCreateJsonFile();
    }
}
