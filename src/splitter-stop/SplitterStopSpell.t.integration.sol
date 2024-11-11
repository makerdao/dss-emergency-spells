// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssTest, DssInstance, MCD, GodMode} from "dss-test/DssTest.sol";
import {SplitterStopSpell} from "./SplitterStopSpell.sol";

interface SplitterLike {
    function rely(address) external;
    function deny(address) external;
    function hop() external view returns (uint256);
}

contract MockAuth {
    function wards(address) external pure returns (uint256) {
        return 1;
    }
}

contract MockSplitterHopReverts is MockAuth {
    function hop() external pure {
        revert();
    }
}

contract SplitterStopSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    address splitterMom;
    SplitterLike splitter;
    SplitterStopSpell spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        splitterMom = dss.chainlog.getAddress("SPLITTER_MOM");
        splitter = SplitterLike(dss.chainlog.getAddress("MCD_SPLIT"));
        spell = new SplitterStopSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testSplitterStopOnSchedule() public {
        uint256 preHop = splitter.hop();
        assertTrue(preHop != type(uint256).max, "before: Splitter already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, false, false, false, address(spell));
        emit Stop();

        spell.schedule();

        uint256 postHop = splitter.hop();
        assertEq(postHop, type(uint256).max, "after: Splitter not stopped");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDoneWhenSplitterMomIsNotWardInSplitter() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        splitter.deny(splitterMom);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenSplitterDoesNotImplementHop() public {
        vm.etch(address(splitter), address(new MockAuth()).code);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenLiteSplitterHopReverts() public {
        vm.etch(address(splitter), address(new MockSplitterHopReverts()).code);

        assertTrue(spell.done(), "spell not done");
    }

    function testRevertSplitterStopWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        uint256 preHop = splitter.hop();
        assertTrue(preHop != type(uint256).max, "before: Splitter already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 postHop = splitter.hop();
        assertEq(postHop, preHop, "after: Splitter stopped unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    event Stop();
}
