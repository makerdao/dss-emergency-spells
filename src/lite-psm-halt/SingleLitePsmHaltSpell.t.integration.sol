// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssTest, DssInstance, MCD, GodMode} from "dss-test/DssTest.sol";
import {DssEmergencySpellLike} from "../DssEmergencySpell.sol";
import {SingleLitePsmHaltSpellFactory, LitePsmLike, Flow} from "./SingleLitePsmHaltSpell.sol";

contract SingleLitePsmHaltSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    address litePsmMom;
    LitePsmLike psm;
    SingleLitePsmHaltSpellFactory factory;


    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        litePsmMom = dss.chainlog.getAddress("LITE_PSM_MOM");
        psm = LitePsmLike(dss.chainlog.getAddress("MCD_LITE_PSM_USDC_A"));
        factory = new SingleLitePsmHaltSpellFactory();
    }

    function testPsmHaltOnScheduleBuy() public {
        _checkPsmHaltOnSchedule(Flow.BUY);
    }

    function testPsmHaltOnScheduleSell() public {
        _checkPsmHaltOnSchedule(Flow.SELL);
    }

    function testPsmHaltOnScheduleBoth() public {
        _checkPsmHaltOnSchedule(Flow.BOTH);
    }

    function _checkPsmHaltOnSchedule(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), flow));
        stdstore.target(chief).sig("hat()").checked_write(address(spell));
        vm.makePersistent(chief);

        uint256 preTin = psm.tin();
        uint256 preTout = psm.tout();
        uint256 halted = psm.HALTED();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertNotEq(preTin, halted, "before: PSM SELL already halted");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertNotEq(preTout, halted, "before: PSM BUY already halted");
        }
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, false, address(spell));
        emit Halt(flow);

        spell.schedule();

        uint256 postTin = psm.tin();
        uint256 postTout = psm.tout();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertEq(postTin, halted, "after: PSM SELL not halted (tin)");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertEq(postTout, halted, "after: PSM BUY not halted (tout)");
        }

        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertPsmHaltWhenItDoesNotHaveTheHat() public {
        Flow flow = Flow.BOTH;
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), flow));

        uint256 preTin = psm.tin();
        uint256 preTout = psm.tout();
        uint256 halted = psm.HALTED();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertNotEq(preTin, halted, "before: PSM SELL already halted");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertNotEq(preTout, halted, "before: PSM BUY already halted");
        }
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 postTin = psm.tin();
        uint256 postTout = psm.tout();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertEq(postTin, preTin, "after: PSM SELL halted unexpectedly (tin)");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertEq(postTout, preTout, "after: PSM BUY halted unexpectedly (tout)");
        }

        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    event Halt(Flow what);
}
