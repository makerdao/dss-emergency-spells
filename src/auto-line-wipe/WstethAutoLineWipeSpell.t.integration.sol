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
import {WstethAutoLineWipeSpell} from "./WstethAutoLineWipeSpell.sol";

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
}

interface LineMomLike {
    function delIlk(bytes32 ilk) external;
}

interface VatLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
}

contract WstethAutoLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address pauseProxy;
    VatLike vat;
    address chief;
    bytes32 WSTETH_A = "WSTETH-A";
    bytes32 WSTETH_B = "WSTETH-B";
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
        spell = new WstethAutoLineWipeSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testAutoLineWipeOnSchedule() public {
        uint256 pmaxLine;
        uint256 pgap;

        (pmaxLine, pgap,,,) = autoLine.ilks(WSTETH_A);
        assertGt(pmaxLine, 0, "WSTETH-A before: auto-line already wiped");
        assertGt(pgap, 0, "WSTETH-A before: auto-line already wiped");
        assertFalse(spell.done(), "WSTETH-A before: spell already done");

        (pmaxLine, pgap,,,) = autoLine.ilks(WSTETH_B);
        assertGt(pmaxLine, 0, "WSTETH-B before: auto-line already wiped");
        assertGt(pgap, 0, "WSTETH-B before: auto-line already wiped");
        assertFalse(spell.done(), "WSTETH-B before: spell already done");

        vm.expectEmit(true, true, true, false);
        emit Wipe(WSTETH_A);
        vm.expectEmit(true, true, true, false);
        emit Wipe(WSTETH_B);
        spell.schedule();

        uint256 maxLine;
        uint256 gap;

        (maxLine, gap,,,) = autoLine.ilks(WSTETH_A);
        assertEq(maxLine, 0, "WSTETH-A after: auto-line not wiped (maxLine)");
        assertEq(gap, 0, "WSTETH-A after: auto-line not wiped (gap)");
        assertTrue(spell.done(), "WSTETH-A after: spell not done");

        (maxLine, gap,,,) = autoLine.ilks(WSTETH_B);
        assertEq(maxLine, 0, "WSTETH-B after: auto-line not wiped (maxLine)");
        assertEq(gap, 0, "WSTETH-B after: auto-line not wiped (gap)");
        assertTrue(spell.done(), "WSTETH-B after: spell not done");
    }

    function testDoneWhenIlkIsNotAddedToLineMom() public {
        uint256 before = vm.snapshotState();

        vm.prank(pauseProxy);
        lineMom.delIlk(WSTETH_A);
        assertFalse(spell.done(), "WSTETH-A spell done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        lineMom.delIlk(WSTETH_B);
        assertFalse(spell.done(), "WSTETH-B spell done");
        vm.revertToState(before);

        vm.startPrank(pauseProxy);
        lineMom.delIlk(WSTETH_A);
        lineMom.delIlk(WSTETH_B);
        assertTrue(spell.done(), "spell not done done");
    }

    function testDoneWhenAutoLineIsNotActiveButLineIsNonZero() public {
        uint256 before = vm.snapshotState();

        spell.schedule();
        assertTrue(spell.done(), "before: spell not done");

        vm.prank(pauseProxy);
        vat.file(WSTETH_A, "line", 10 ** 45);
        assertFalse(spell.done(), "WSTETH-A after: spell still done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        vat.file(WSTETH_B, "line", 10 ** 45);
        assertFalse(spell.done(), "WSTETH-B after: spell still done");
        vm.revertToState(before);
    }

    function testRevertAutoLineWipeWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        vm.expectRevert();
        spell.schedule();
    }

    event Wipe(bytes32 indexed ilk);
}
