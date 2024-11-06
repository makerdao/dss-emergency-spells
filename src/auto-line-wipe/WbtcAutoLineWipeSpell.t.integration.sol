// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssTest, DssInstance, MCD} from "dss-test/DssTest.sol";
import {DssEmergencySpellLike} from "../DssEmergencySpell.sol";
import {WbtcAutoLineWipeSpell} from "./WbtcAutoLineWipeSpell.sol";

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
    function setIlk(bytes32 ilk, uint256 maxLine, uint256 gap, uint256 ttl) external;
}

interface LineMomLike {
    function delIlk(bytes32 ilk) external;
}

interface VatLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
}

contract WbtcAutoLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address pauseProxy;
    VatLike vat;
    address chief;
    bytes32 WBTC_A = "WBTC-A";
    bytes32 WBTC_B = "WBTC-B";
    bytes32 WBTC_C = "WBTC-C";
    LineMomLike lineMom;
    AutoLineLike autoLine;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vat = VatLike(dss.chainlog.getAddress("MCD_VAT"));
        chief = dss.chainlog.getAddress("MCD_ADM");
        lineMom = LineMomLike(dss.chainlog.getAddress("LINE_MOM"));
        autoLine = AutoLineLike(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE"));
        spell = new WbtcAutoLineWipeSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testAutoLineWipeOnSchedule() public {
        uint256 pmaxLine;
        uint256 pgap;

        // WBTC debt ceiling was set to zero when this tests was written, so we need to overwrite the state.
        vm.startPrank(pauseProxy);
        autoLine.setIlk(WBTC_A, 1, 1, 1);
        autoLine.setIlk(WBTC_B, 1, 1, 1);
        autoLine.setIlk(WBTC_C, 1, 1, 1);
        vm.stopPrank();

        (pmaxLine, pgap,,,) = autoLine.ilks(WBTC_A);
        assertGt(pmaxLine, 0, "WBTC-A before: auto-line already wiped");
        assertGt(pgap, 0, "WBTC-A before: auto-line already wiped");
        assertFalse(spell.done(), "WBTC-A before: spell already done");

        (pmaxLine, pgap,,,) = autoLine.ilks(WBTC_B);
        assertGt(pmaxLine, 0, "WBTC-B before: auto-line already wiped");
        assertGt(pgap, 0, "WBTC-B before: auto-line already wiped");
        assertFalse(spell.done(), "WBTC-B before: spell already done");

        (pmaxLine, pgap,,,) = autoLine.ilks(WBTC_C);
        assertGt(pmaxLine, 0, "WBTC-C before: auto-line already wiped");
        assertGt(pgap, 0, "WBTC-C before: auto-line already wiped");
        assertFalse(spell.done(), "WBTC-C before: spell already done");

        vm.expectEmit(true, true, true, false);
        emit Wipe(WBTC_A);
        vm.expectEmit(true, true, true, false);
        emit Wipe(WBTC_B);
        vm.expectEmit(true, true, true, false);
        emit Wipe(WBTC_C);
        spell.schedule();

        uint256 maxLine;
        uint256 gap;

        (maxLine, gap,,,) = autoLine.ilks(WBTC_A);
        assertEq(maxLine, 0, "WBTC-A after: auto-line not wiped (maxLine)");
        assertEq(gap, 0, "WBTC-A after: auto-line not wiped (gap)");
        assertTrue(spell.done(), "WBTC-A after: spell not done");

        (maxLine, gap,,,) = autoLine.ilks(WBTC_B);
        assertEq(maxLine, 0, "WBTC-B after: auto-line not wiped (maxLine)");
        assertEq(gap, 0, "WBTC-B after: auto-line not wiped (gap)");
        assertTrue(spell.done(), "WBTC-B after: spell not done");

        (maxLine, gap,,,) = autoLine.ilks(WBTC_C);
        assertEq(maxLine, 0, "WBTC-C after: auto-line not wiped (maxLine)");
        assertEq(gap, 0, "WBTC-C after: auto-line not wiped (gap)");
        assertTrue(spell.done(), "WBTC-C after: spell not done");
    }

    function testDoneWhenIlkIsNotAddedToLineMom() public {
        uint256 before = vm.snapshotState();

        vm.prank(pauseProxy);
        lineMom.delIlk(WBTC_A);
        assertFalse(spell.done(), "WBTC-A spell done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        lineMom.delIlk(WBTC_B);
        assertFalse(spell.done(), "WBTC-B spell done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        lineMom.delIlk(WBTC_C);
        assertFalse(spell.done(), "WBTC-C spell done");
        vm.revertToState(before);

        vm.startPrank(pauseProxy);
        lineMom.delIlk(WBTC_A);
        lineMom.delIlk(WBTC_B);
        lineMom.delIlk(WBTC_C);
        assertTrue(spell.done(), "spell not done done");
    }

    function testDoneWhenAutoLineIsNotActiveButLineIsNonZero() public {
        uint256 before = vm.snapshotState();

        spell.schedule();
        assertTrue(spell.done(), "before: spell not done");

        vm.prank(pauseProxy);
        vat.file(WBTC_A, "line", 10 ** 45);
        assertFalse(spell.done(), "WBTC-A after: spell still done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        vat.file(WBTC_B, "line", 10 ** 45);
        assertFalse(spell.done(), "WBTC-B after: spell still done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        vat.file(WBTC_C, "line", 10 ** 45);
        assertFalse(spell.done(), "WBTC-C after: spell still done");
        vm.revertToState(before);
    }

    function testRevertAutoLineWipeWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        vm.expectRevert();
        spell.schedule();
    }

    event Wipe(bytes32 indexed ilk);
}
