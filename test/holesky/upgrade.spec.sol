// BSD 3-Clause License
pragma solidity ^0.8.24;

import {SingleVault} from "src/SingleVault.sol";
import {WETH9} from "test/mocks/MockWETH.sol";
import {SetupHelper} from "test/helpers/Setup.sol";
import {IVaultFactory} from "src/interface/IVaultFactory.sol";
import {ISingleVault,SingleVault} from "src/SingleVault.sol";
import {IVault,Vault} from "test/mocks/MaxVaultMock.sol";
import {TimelockController as TLC} from "src/Common.sol";
import {HoleskyActors} from "script/Actors.sol";
import {HoleskyContracts} from "script/Contracts.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {MockBuffer} from "test/mocks/MockBuffer.sol";
import {MockETHRates} from "test/mocks/MockETHRates.sol";

contract SingleVaultHoleskyUpgradeTests is Test, SetupHelper, HoleskyActors {
    ISingleVault public vault;
    WETH9 public weth;

    function setUp() public {
        weth = WETH9(payable(WETH));
        vault = ISingleVault(HoleskyContracts.YNETHX);

        vm.label(HoleskyContracts.TIMELOCK, "TIMELOCK");
        vm.label(HoleskyContracts.PROXY_ADMIN, "PROXY_ADMIN");
        vm.label(HoleskyContracts.YNETHX, "ynETHx");
        vm.label(HoleskyContracts.WETH, "WETH");
    }

    modifier onlyHolesky() {
        if (block.chainid != 17000) return;
        _;
    }
    
    function test_Holesky_Vault_Upgrade() public onlyHolesky {
        ISingleVault newVault = new SingleVault();
        upgrader(address(newVault));
    }

    function test_Holesky_Vault_UpgradeMaxVault() public onlyHolesky {
        address USER = address(420);

        uint256 depositAmount = 10 ether;
        deal(USER, depositAmount);
        vm.startPrank(USER);
        (bool success,) = address(vault).call{value: depositAmount}("");
        require(success, "Send ETH failed");

        vm.stopPrank();

        uint256 currentTotalAssets = vault.totalAssets();
        
        // Upgrade to the max vault
        IVault newVault = new Vault();
        upgrader(address(newVault));
        IVault maxVault = IVault(address(vault));

        // configure basics
        vm.startPrank(ADMIN);
        maxVault.addAsset(address(weth), 18);
        assertEq(maxVault.asset(), address(weth));
        MockBuffer buffer = new MockBuffer();
        MockETHRates rates = new MockETHRates();
        maxVault.addStrategy(address(buffer), 18);
        maxVault.setRateProvider(address(rates));
        maxVault.processAccounting();
        uint256 maxVaultTotalAssets = vault.totalAssets();
        assertEq(maxVaultTotalAssets, currentTotalAssets);
    }

    function test_Holesky_Vault_maxVaultUpgradeTestDesposit() public onlyHolesky {

        IVault newVault = new Vault();

        vm.label(address(newVault), "MAX_IMPL");
        upgrader(address(newVault));

        IVault maxVault = IVault(address(vault));

        vm.startPrank(ADMIN);
        maxVault.addAsset(address(weth), 18);
        assertEq(maxVault.asset(), address(weth));
        
        MockBuffer buffer = new MockBuffer();
        MockETHRates rates = new MockETHRates();
        maxVault.addStrategy(address(buffer), 18);
        maxVault.setRateProvider(address(rates));
        maxVault.processAccounting();
        vm.stopPrank();

        vm.label(address(maxVault), "MAX_VAULT");
        
        address USER1 = address(101);
        address USER2 = address(102);

        uint256 initialTotalAssets = maxVault.totalAssets();

        // Simulate deposits
        uint256 depositAmount1 = 5 ether;
        uint256 depositAmount2 = 10 ether;

        deal(USER1, depositAmount1);
        vm.prank(USER1);
        (bool success,) = address(weth).call{value: depositAmount1}("");
        require(success);
        assertEq(weth.balanceOf(USER1), depositAmount1, "User1 should have the correct weth balance");

        deal(USER2, depositAmount2);
        vm.prank(USER2);
        (bool success1,) = address(weth).call{value: depositAmount2}("");
        require(success1);
        assertEq(weth.balanceOf(USER2), depositAmount2, "User2 should have the correct weth balance");

        vm.startPrank(USER1);
        weth.approve(address(maxVault), depositAmount1);
        maxVault.deposit(depositAmount1, USER1);
        assertEq(maxVault.balanceOf(USER1), depositAmount1, "User1 should have the correct ynETHx balance");
        vm.stopPrank();

        vm.startPrank(USER2);
        weth.approve(address(maxVault), depositAmount2);
        maxVault.deposit(depositAmount2, USER2);
        maxVault.totalAssets();

        assertEq(maxVault.balanceOf(USER2), depositAmount2, "User2 should have the correct ynETHx balance");
        vm.stopPrank();

        maxVault.processAccounting();
        uint256 currentTotalAssets = maxVault.totalAssets();
        assertEq(currentTotalAssets, initialTotalAssets + depositAmount1 + depositAmount2, "Current total matches deposited total");
    }

    function upgrader(address newVault) internal {
        deal(ADMIN, 100 ether);
        deal(PROPOSER_1, 100 ether);
        deal(EXECUTOR_1, 100 ether);

        // the timelock on the factory is the admin for proxy upgrades
        TLC timelock = TLC(payable(HoleskyContracts.TIMELOCK));

        // schedule a proxy upgrade transaction on the timelock
        // the traget is the proxy admin, Admin
        address target = HoleskyContracts.PROXY_ADMIN;
        uint256 value = 0;

        string memory selector = "upgradeAndCall(address,address,bytes)";

        bytes memory data = abi.encodeWithSignature(selector, HoleskyContracts.YNETHX, newVault, "");
      
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("chad");

        uint256 delay = 10;
        vm.prank(PROPOSER_1);
        timelock.schedule(target, value, data, predecessor, salt, delay);

        bytes32 id = keccak256(abi.encode(target, value, data, predecessor, salt));
        assert(timelock.getOperationState(id) == TLC.OperationState.Waiting);

        assertEq(timelock.isOperationReady(id), false); 
        assertEq(timelock.isOperationDone(id), false);
        assertEq(timelock.isOperation(id), true);

        //execute the transaction
        vm.warp(block.timestamp + 10);
        assertEq(timelock.isOperationReady(id), true);

        vm.prank(EXECUTOR_1);
        timelock.execute(target, value, data, predecessor, salt);

        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), true);
        assertEq(uint256(timelock.getOperationState(id)), uint256(TLC.OperationState.Done));
    }
}