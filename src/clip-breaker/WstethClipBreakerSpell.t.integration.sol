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
import {WstethClipBreakerSpell} from "./WstethClipBreakerSpell.sol";

interface IlkRegistryLike {
    function xlip(bytes32 ilk) external view returns (address);
    function file(bytes32 ilk, bytes32 what, address data) external;
}

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface ClipLike {
    function stopped() external view returns (uint256);
    function deny(address who) external;
}

contract WstethClipBreakerSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address pauseProxy;
    address chief;
    IlkRegistryLike ilkReg;
    bytes32 WSTETH_A = "WSTETH-A";
    bytes32 WSTETH_B = "WSTETH-B";
    ClipperMomLike clipperMom;
    ClipLike clipA;
    ClipLike clipB;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        chief = dss.chainlog.getAddress("MCD_ADM");
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        clipperMom = ClipperMomLike(dss.chainlog.getAddress("CLIPPER_MOM"));
        clipA = ClipLike(ilkReg.xlip(WSTETH_A));
        clipB = ClipLike(ilkReg.xlip(WSTETH_B));
        spell = new WstethClipBreakerSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testClipBreakerOnSchedule() public {
        assertEq(clipA.stopped(), 0, "WSTETH-A before: clip already stopped");
        assertFalse(spell.done(), "WSTETH-A before: spell already done");
        assertEq(clipB.stopped(), 0, "WSTETH-B before: clip already stopped");
        assertFalse(spell.done(), "WSTETH-B before: spell already done");

        vm.expectEmit(true, true, true, true);
        emit SetBreaker(WSTETH_A, address(clipA));
        vm.expectEmit(true, true, true, true);
        emit SetBreaker(WSTETH_B, address(clipB));
        spell.schedule();

        assertEq(clipA.stopped(), 3, "WSTETH-A after: clip not stopped");
        assertTrue(spell.done(), "WSTETH-A after: spell not done");
        assertEq(clipB.stopped(), 3, "WSTETH-B after: clip not stopped");
        assertTrue(spell.done(), "WSTETH-B after: spell not done");
    }

    function testDoneWhenClipIsNotSetInIlkReg() public {
        vm.startPrank(pauseProxy);
        ilkReg.file(WSTETH_A, "xlip", address(0));
        ilkReg.file(WSTETH_B, "xlip", address(0));
        vm.stopPrank();

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenClipperMomIsNotWardInClip() public {
        uint256 before = vm.snapshotState();

        vm.prank(pauseProxy);
        clipA.deny(address(clipperMom));
        assertFalse(spell.done(), "WSTETH-A spell already done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        clipB.deny(address(clipperMom));
        assertFalse(spell.done(), "WSTETH-B spell already done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        assertFalse(spell.done(), "WSTETH-C spell already done");
        vm.revertToState(before);

        vm.startPrank(pauseProxy);
        clipA.deny(address(clipperMom));
        clipB.deny(address(clipperMom));
        vm.stopPrank();
        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertClipBreakerWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        vm.expectRevert();
        spell.schedule();
    }

    event SetBreaker(bytes32 indexed ilk, address indexed clip);
}
