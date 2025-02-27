// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssTest, DssInstance, MCD, GodMode} from "dss-test/DssTest.sol";
import {DSPCHaltSpell} from "./DSPCHaltSpell.sol";

interface DSPCLike {
    function rely(address) external;
    function deny(address) external;
    function bad() external view returns (uint256);
}

contract MockAuth {
    function wards(address) external pure returns (uint256) {
        return 1;
    }
}

contract MockDSPCBadReverts is MockAuth {
    function bad() external pure {
        revert();
    }
}

contract DSPCHaltSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    address dspcMom;
    DSPCLike dspc;
    DSPCHaltSpell spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        dspcMom = dss.chainlog.getAddress("DSPC_MOM");
        dspc = DSPCLike(dss.chainlog.getAddress("MCD_DSPC"));
        spell = new DSPCHaltSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testDSPCHaltOnSchedule() public {
        uint256 preBad = dspc.bad();
        assertTrue(preBad != 1, "before: DSPC already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, false, false, false, address(spell));
        emit Halt();

        spell.schedule();

        uint256 postBad = dspc.bad();
        assertEq(postBad, 1, "after: DSPC not stopped");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDoneWhenDSPCMomIsNotWardInDSPC() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        dspc.deny(dspcMom);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenDSPCDoesNotImplementBad() public {
        vm.etch(address(dspc), address(new MockAuth()).code);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenLiteDSPCHaltReverts() public {
        vm.etch(address(dspc), address(new MockDSPCBadReverts()).code);

        assertTrue(spell.done(), "spell not done");
    }

    function testRevertDSPCHaltWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        uint256 preBad = dspc.bad();
        assertTrue(preBad != 1, "before: DSPC already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 postBad = dspc.bad();
        assertEq(postBad, preBad, "after: DSPC stopped unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    event Halt();
}
