// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("ABELLE");
    uint256 constant SEND_VALUE = 0.1 ether; //10**17
    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarisFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5 * 10 ** 18);
    }

    function testOwnerisMsgSender() public view {
        assertEq(fundMe.getOwner(), address(msg.sender));
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); //Telling the foundry that the next line should revert
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testAddsFunderToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        //ARRANGE- INITIALIZING VARIABLES, OBJECTS AND PREPARING CONDITIONS
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        //ACT- PERFORMS ACTION TO BE TESTED
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank;
        //ASSERT- WE COMPARE RECEIVED OUTPUT WITH EXPECTED OUTPUT
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10; //WE USE UINT160 SINCE IT SAVES US FROM USING THE CASTING COMMAND ON THE TERMINAL TO CONVERT IT
        uint160 startingFunderIndex = 1;

        //THE FOR LOOP PRANKS AND DEALS ALL THE NUMBER OF FUNDING ADDRESSES
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //HOAX PRANKS AND DEALS THE ADDRESS (PRANK + DEAL)
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance; //RECORDING THE FUNDING CONTRACT'S BALANCE
        uint256 startingOwnerBalance = fundMe.getOwner().balance; //RECORDS THE BALANCE OF THE CONTRACT OWNER

        vm.txGasPrice(GAS_PRICE);
        uint256 gasStart = gasleft();
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank;

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log("gas consumed by withdraw fn: %d gas", gasUsed);

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
        //assert((numberOfFunders + 1) * SEND_VALUE == fundMe.getOwner().balance);
    }

    function testCheaperWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        //THE FOR LOOP PRANKS AND DEALS ALL THE NUMBER OF FUNDING ADDRESSES
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //HOAX PRANKS AND DEALS THE ADDRESS (PRANK + DEAL)
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance; //RECORDING THE FUNDING CONTRACT'S BALANCE
        uint256 startingOwnerBalance = fundMe.getOwner().balance; //RECORDS THE BALANCE OF THE CONTRACT OWNER

        vm.txGasPrice(GAS_PRICE);
        uint256 gasStart = gasleft();
        vm.startPrank(fundMe.getOwner());
        fundMe.CheaperWithdraw();
        vm.stopPrank;

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log("gas consumed by withdraw fn: %d gas", gasUsed);

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
        //assert((numberOfFunders + 1) * SEND_VALUE == fundMe.getOwner().balance);
    }
}
