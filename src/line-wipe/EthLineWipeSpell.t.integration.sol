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
import {EthLineWipeSpell} from "./EthLineWipeSpell.sol";

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

contract EthLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address pauseProxy;
    VatLike vat;
    address chief;
    bytes32 ETH_A = "ETH-A";
    bytes32 ETH_B = "ETH-B";
    bytes32 ETH_C = "ETH-C";
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
        spell = new EthLineWipeSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testAutoLineWipeOnSchedule() public {
        uint256 pmaxLine;
        uint256 pgap;

        (pmaxLine, pgap,,,) = autoLine.ilks(ETH_A);
        assertGt(pmaxLine, 0, "ETH-A before: auto-line maxLine already wiped");
        assertGt(pgap, 0, "ETH-A before: auto-line gap already wiped");
        assertFalse(spell.done(), "ETH-A before: spell already done");

        (pmaxLine, pgap,,,) = autoLine.ilks(ETH_B);
        assertGt(pmaxLine, 0, "ETH-B before: auto-line maxLine already wiped");
        assertGt(pgap, 0, "ETH-B before: auto-line gap already wiped");
        assertFalse(spell.done(), "ETH-B before: spell already done");

        (pmaxLine, pgap,,,) = autoLine.ilks(ETH_C);
        assertGt(pmaxLine, 0, "ETH-C before: auto-line maxLine already wiped");
        assertGt(pgap, 0, "ETH-C before: auto-line gap already wiped");
        assertFalse(spell.done(), "ETH-C before: spell already done");

        vm.expectEmit(true, true, true, false);
        emit Wipe(ETH_A);
        vm.expectEmit(true, true, true, false);
        emit Wipe(ETH_B);
        vm.expectEmit(true, true, true, false);
        emit Wipe(ETH_C);
        spell.schedule();

        uint256 maxLine;
        uint256 gap;

        (maxLine, gap,,,) = autoLine.ilks(ETH_A);
        assertEq(maxLine, 0, "ETH-A after: auto-line maxLine not wiped");
        assertEq(gap, 0, "ETH-A after: auto-line gap not wiped (gap)");
        assertTrue(spell.done(), "ETH-A after: spell not done");

        (maxLine, gap,,,) = autoLine.ilks(ETH_B);
        assertEq(maxLine, 0, "ETH-B after: auto-line maxLine not wiped");
        assertEq(gap, 0, "ETH-B after: auto-line gap not wiped");
        assertTrue(spell.done(), "ETH-B after: spell not done");

        (maxLine, gap,,,) = autoLine.ilks(ETH_C);
        assertEq(maxLine, 0, "ETH-C after: auto-line maxLine not wiped");
        assertEq(gap, 0, "ETH-C after: auto-line gap not wiped (gap)");
        assertTrue(spell.done(), "ETH-C after: spell not done");
    }

    function testDoneWhenIlkIsNotAddedToLineMom() public {
        uint256 before = vm.snapshotState();

        vm.prank(pauseProxy);
        lineMom.delIlk(ETH_A);
        assertFalse(spell.done(), "ETH-A spell done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        lineMom.delIlk(ETH_B);
        assertFalse(spell.done(), "ETH-B spell done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        lineMom.delIlk(ETH_C);
        assertFalse(spell.done(), "ETH-C spell done");
        vm.revertToState(before);

        vm.startPrank(pauseProxy);
        lineMom.delIlk(ETH_A);
        lineMom.delIlk(ETH_B);
        lineMom.delIlk(ETH_C);
        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenAutoLineIsNotActiveButLineIsNonZero() public {
        uint256 before = vm.snapshotState();

        spell.schedule();
        assertTrue(spell.done(), "before: spell not done");

        vm.prank(pauseProxy);
        vat.file(ETH_A, "line", 10 ** 45);
        assertFalse(spell.done(), "ETH-A after: spell still done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        vat.file(ETH_B, "line", 10 ** 45);
        assertFalse(spell.done(), "ETH-B after: spell still done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        vat.file(ETH_C, "line", 10 ** 45);
        assertFalse(spell.done(), "ETH-C after: spell still done");
        vm.revertToState(before);
    }

    function testRevertAutoLineWipeWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        vm.expectRevert();
        spell.schedule();
    }

    event Wipe(bytes32 indexed ilk);
}
