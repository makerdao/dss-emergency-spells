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
import {MultiLineWipeSpell, MultiLineWipeFactory} from "./MultiLineWipeSpell.sol";

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


abstract contract MultiLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address pauseProxy;
    VatLike vat;
    address chief;
    LineMomLike lineMom;
    AutoLineLike autoLine;
    bytes32[] ilks;
    MultiLineWipeFactory factory;
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
        _setUpSub();
        factory = new MultiLineWipeFactory();
        spell = DssEmergencySpellLike(factory.deploy(ilks));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function _setUpSub() internal virtual;

    function testAutoLineWipeOnSchedule() public {
        uint256 pmaxLine;
        uint256 pgap;

        (pmaxLine, pgap,,,) = autoLine.ilks(ilks[0]);
        assertGt(pmaxLine, 0, "ilk0: before: auto-line maxLine already wiped");
        assertGt(pgap, 0, "ilk0: before: auto-line gap already wiped");
        assertFalse(spell.done(), "ilk0: before: spell already done");

        (pmaxLine, pgap,,,) = autoLine.ilks(ilks[1]);
        assertGt(pmaxLine, 0, "ilk1: before: auto-line maxLine already wiped");
        assertGt(pgap, 0, "ilk1: before: auto-line gap already wiped");
        assertFalse(spell.done(), "ilk1: before: spell already done");

        if (ilks.length > 2) {
            (pmaxLine, pgap,,,) = autoLine.ilks(ilks[2]);
            assertGt(pmaxLine, 0, "ilk2: before: auto-line maxLine already wiped");
            assertGt(pgap, 0, "ilk2: before: auto-line gap already wiped");
            assertFalse(spell.done(), "ilk2: before: spell already done");
        }

        vm.expectEmit(true, true, true, false);
        emit Wipe(ilks[0]);
        vm.expectEmit(true, true, true, false);
        emit Wipe(ilks[1]);
        if (ilks.length > 2) {
            vm.expectEmit(true, true, true, false);
            emit Wipe(ilks[2]);
        }
        spell.schedule();

        uint256 maxLine;
        uint256 gap;

        (maxLine, gap,,,) = autoLine.ilks(ilks[0]);
        assertEq(maxLine, 0, "ilk0: after: auto-line maxLine not wiped");
        assertEq(gap, 0, "ilk0: after: auto-line gap not wiped (gap)");
        assertTrue(spell.done(), "ilk0: after: spell not done");

        (maxLine, gap,,,) = autoLine.ilks(ilks[1]);
        assertEq(maxLine, 0, "ilk1: after: auto-line maxLine not wiped");
        assertEq(gap, 0, "ilk1: after: auto-line gap not wiped");
        assertTrue(spell.done(), "ilk1: after: spell not done");

        if (ilks.length > 2) {
            (maxLine, gap,,,) = autoLine.ilks(ilks[2]);
            assertEq(maxLine, 0, "ilk2: after: auto-line maxLine not wiped");
            assertEq(gap, 0, "ilk2: after: auto-line gap not wiped (gap)");
            assertTrue(spell.done(), "ilk2: after: spell not done");
        }
    }

    function testDoneWhenIlkIsNotAddedToLineMom() public {
        uint256 before = vm.snapshotState();

        vm.prank(pauseProxy);
        lineMom.delIlk(ilks[0]);
        assertFalse(spell.done(), "ilk0: spell done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        lineMom.delIlk(ilks[1]);
        assertFalse(spell.done(), "ilk1: spell done");
        vm.revertToState(before);

        if (ilks.length > 2) {
            vm.prank(pauseProxy);
            lineMom.delIlk(ilks[2]);
            assertFalse(spell.done(), "ilk2: spell done");
            vm.revertToState(before);
        }

        vm.startPrank(pauseProxy);
        lineMom.delIlk(ilks[0]);
        lineMom.delIlk(ilks[1]);
        if (ilks.length > 2) {
            lineMom.delIlk(ilks[2]);
        }
        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenAutoLineIsNotActiveButLineIsNonZero() public {
        uint256 before = vm.snapshotState();

        spell.schedule();
        assertTrue(spell.done(), "before: spell not done");

        vm.prank(pauseProxy);
        vat.file(ilks[0], "line", 10 ** 45);
        assertFalse(spell.done(), "ilk0: after: spell still done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        vat.file(ilks[1], "line", 10 ** 45);
        assertFalse(spell.done(), "ilk1: after: spell still done");
        vm.revertToState(before);

        if (ilks.length > 2) {
            vm.prank(pauseProxy);
            vat.file(ilks[2], "line", 10 ** 45);
            assertFalse(spell.done(), "ilk2: after: spell still done");
            vm.revertToState(before);
        }
    }

    function testRevertAutoLineWipeWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        vm.expectRevert();
        spell.schedule();
    }

    event Wipe(bytes32 indexed ilk);
}

contract EthMultiLineWipeSpellTest is MultiLineWipeSpellTest {
    function _setUpSub() internal override {
        ilks = new bytes32[](3);
        ilks[0] = "ETH-A";
        ilks[1] = "ETH-B";
        ilks[2] = "ETH-C";
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | Multi Line Wipe: ETH-A, ETH-B, ETH-C");
    }
}

contract WstethMultiLineWipeSpellTest is MultiLineWipeSpellTest {
    function _setUpSub() internal override {
        ilks = new bytes32[](2);
        ilks[0] = "WSTETH-A";
        ilks[1] = "WSTETH-B";
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | Multi Line Wipe: WSTETH-A, WSTETH-B");
    }
}

contract WbtcMultiLineWipeSpellTest is MultiLineWipeSpellTest {
    function _setUpSub() internal override {
        ilks = new bytes32[](3);
        ilks[0] = "WBTC-A";
        ilks[1] = "WBTC-B";
        ilks[2] = "WBTC-C";

        // WBTC debt ceiling was set to zero when this test was written, so we need to overwrite the state.
        vm.startPrank(pauseProxy);
        autoLine.setIlk(ilks[0], 1, 1, 1);
        autoLine.setIlk(ilks[1], 1, 1, 1);
        autoLine.setIlk(ilks[2], 1, 1, 1);
        vm.stopPrank();
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | Multi Line Wipe: WBTC-A, WBTC-B, WBTC-C");
    }
}
