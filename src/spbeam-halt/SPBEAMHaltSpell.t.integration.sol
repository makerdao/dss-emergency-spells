// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssTest, DssInstance, MCD, GodMode} from "dss-test/DssTest.sol";
import {SPBEAMHaltSpell} from "./SPBEAMHaltSpell.sol";

interface SPBEAMLike {
    function rely(address) external;
    function deny(address) external;
    function bad() external view returns (uint256);
}

contract MockAuth {
    function wards(address) external pure returns (uint256) {
        return 1;
    }
}

contract MockSPBEAMBadReverts is MockAuth {
    function bad() external pure {
        revert();
    }
}

contract SPBEAMHaltSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    address spbeamMom;
    SPBEAMLike spbeam;
    SPBEAMHaltSpell spell;

    function setUp() public {
        vm.createSelectFork("spbeam");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        spbeamMom = dss.chainlog.getAddress("SPBEAM_MOM");
        spbeam = SPBEAMLike(dss.chainlog.getAddress("MCD_SP_BEAM"));
        spell = new SPBEAMHaltSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testSPBEAMHaltOnSchedule() public {
        uint256 preBad = spbeam.bad();
        assertTrue(preBad != 1, "before: SPBEAM already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, false, false, false, address(spell));
        emit Halt();

        spell.schedule();

        uint256 postBad = spbeam.bad();
        assertEq(postBad, 1, "after: SPBEAM not stopped");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDoneWhenSPBEAMMomIsNotWardInSPBEAM() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        spbeam.deny(spbeamMom);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenSPBEAMDoesNotImplementBad() public {
        vm.etch(address(spbeam), address(new MockAuth()).code);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenLiteSPBEAMHaltReverts() public {
        vm.etch(address(spbeam), address(new MockSPBEAMBadReverts()).code);

        assertTrue(spell.done(), "spell not done");
    }

    function testRevertSPBEAMHaltWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        uint256 preBad = spbeam.bad();
        assertTrue(preBad != 1, "before: SPBEAM already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 postBad = spbeam.bad();
        assertEq(postBad, preBad, "after: SPBEAM stopped unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    event Halt();
}
