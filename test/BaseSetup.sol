// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "script/lib/RusdDeployer.sol";
import "script/lib/Create3Deployer.sol";

import "src/RUSD.sol";
import "src/YUSD.sol";
import "src/RUSDOmnichainAdapter.sol";
import "src/RUSDDataHub.sol";
import "src/extensions/Base.sol";

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "@layerzerolabs/create3-factory/contracts/ICREATE3Factory.sol";

import "test/_utils/LayerZeroDevtoolsHelper.sol";

contract BaseSetup is LayerZeroDevtoolsHelper {
    using RusdDeployer for ICREATE3Factory;
    using Create3Deployer for ICREATE3Factory;

    uint96 public constant MINT_AMOUNT = 1e6;
    uint32 public constant ROUND_BP = 1e4;

    bytes public constant mockData = "mock";

    ICREATE3Factory public create3Factory;

    RUSD public rusd;
    YUSD public yusd;
    RUSDDataHubMainChain public rusdDataHub;
    RUSDOmnichainAdapter public adapter;

    ICREATE3Factory public create3Factory2;

    RUSD public rusd2;
    RUSDDataHub public rusdDataHub2;
    RUSDOmnichainAdapter public adapter2;

    address public user = makeAddr("user");

    uint32 twabPeriodLength = 1 days;

    function setUp() public virtual override {
        super.setUp();

        _beforeSetUp();
        _setUp();
        _afterSetUp();
    }

    function _setUp() internal virtual {
        create3Factory = Create3Deployer.deploy_create3Factory("RUSD.CREATE3Factory");
        create3Factory2 = Create3Deployer.deploy_create3Factory("RUSD.CREATE3Factory2");

        rusdDataHub = create3Factory.deploy_RUSDDataHubMainChain(address(this), address(this));
        rusd = RUSD(create3Factory.deploy_RUSD(rusdDataHub));
        yusd = YUSD(
            create3Factory.deploy_YUSD(
                rusdDataHub, twabPeriodLength, uint32(block.timestamp), ROUND_BP, 100 days
            )
        );
        adapter = RUSDOmnichainAdapter(
            create3Factory.deploy_RUSDOmnichainAdapter(rusdDataHub, address(endPointA))
        );

        rusdDataHub.setRUSD(address(rusd));
        rusdDataHub.setYUSD(address(yusd));
        rusdDataHub.setOmnichainAdapter(address(adapter));

        rusdDataHub2 = RUSDDataHub(create3Factory2.deploy_RUSDDataHub(address(this), address(this)));
        rusd2 = RUSD(create3Factory2.deploy_RUSD(rusdDataHub2));
        adapter2 = RUSDOmnichainAdapter(
            create3Factory2.deploy_RUSDOmnichainAdapter(rusdDataHub2, address(endPointB))
        );

        rusdDataHub2.setRUSD(address(rusd2));
        rusdDataHub2.setOmnichainAdapter(address(adapter2));

        address[] memory adapters = new address[](2);
        adapters[0] = address(adapter);
        adapters[1] = address(adapter2);

        wireOApps(adapters);

        vm.deal(address(this), 1 ether);
        vm.deal(address(adapter), 1 ether);
        vm.deal(address(adapter2), 1 ether);

        rusd.mint(address(this), MINT_AMOUNT, mockData);
        rusd2.mint(address(this), MINT_AMOUNT, mockData);

        rusd.approve(address(adapter), type(uint256).max);
        rusd2.approve(address(adapter2), type(uint256).max);
        rusd.approve(address(yusd), type(uint256).max);

        // All tests math rely on ROUND_BP = x2 per round
        if (ROUND_BP != yusd.BP_PRECISION()) {
            assertEq(ROUND_BP, yusd.BP_PRECISION(), "ROUND_BP is not equal to YUSD.BP_PRECISION");
        }
    }

    function _setLabels() internal {
        vm.label(address(rusd), "RUSD");
        vm.label(address(yusd), "YUSD");
        vm.label(address(rusdDataHub), "RUSDDataHub");
        vm.label(address(adapter), "RUSDOmnichainAdapter");
        vm.label(address(endPointA), "EndPointA");
        vm.label(address(endPointB), "EndPointB");
        vm.label(address(this), "THIS");
        vm.label(address(user), "USER");

        vm.label(address(rusd2), "RUSD2");
        vm.label(address(rusdDataHub2), "RUSDDataHub2");
        vm.label(address(adapter2), "RUSDOmnichainAdapter2");
    }

    function _beforeSetUp() internal virtual {}

    function _afterSetUp() internal virtual {}
}
