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
import {EthClipBreakerSpell} from "./EthClipBreakerSpell.sol";

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

contract EthClipBreakerSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address pauseProxy;
    address chief;
    IlkRegistryLike ilkReg;
    bytes32 ETH_A = "ETH-A";
    bytes32 ETH_B = "ETH-B";
    bytes32 ETH_C = "ETH-C";
    ClipperMomLike clipperMom;
    ClipLike clipA;
    ClipLike clipB;
    ClipLike clipC;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        chief = dss.chainlog.getAddress("MCD_ADM");
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        clipperMom = ClipperMomLike(dss.chainlog.getAddress("CLIPPER_MOM"));
        clipA = ClipLike(ilkReg.xlip(ETH_A));
        clipB = ClipLike(ilkReg.xlip(ETH_B));
        clipC = ClipLike(ilkReg.xlip(ETH_C));
        spell = new EthClipBreakerSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testClipBreakerOnSchedule() public {
        assertEq(clipA.stopped(), 0, "ETH-A before: clip already stopped");
        assertFalse(spell.done(), "ETH-A before: spell already done");
        assertEq(clipB.stopped(), 0, "ETH-B before: clip already stopped");
        assertFalse(spell.done(), "ETH-B before: spell already done");
        assertEq(clipC.stopped(), 0, "ETH-C before: clip already stopped");
        assertFalse(spell.done(), "ETH-C before: spell already done");

        vm.expectEmit(true, true, true, true);
        emit SetBreaker(ETH_A, address(clipA));
        vm.expectEmit(true, true, true, true);
        emit SetBreaker(ETH_B, address(clipB));
        vm.expectEmit(true, true, true, true);
        emit SetBreaker(ETH_C, address(clipC));
        spell.schedule();

        assertEq(clipA.stopped(), 3, "ETH-A after: clip not stopped");
        assertTrue(spell.done(), "ETH-A after: spell not done");
        assertEq(clipB.stopped(), 3, "ETH-B after: clip not stopped");
        assertTrue(spell.done(), "ETH-B after: spell not done");
        assertEq(clipC.stopped(), 3, "ETH-C after: clip not stopped");
        assertTrue(spell.done(), "ETH-C after: spell not done");
    }

    function testDoneWhenClipIsNotSetInIlkReg() public {
        vm.startPrank(pauseProxy);
        ilkReg.file(ETH_A, "xlip", address(0));
        ilkReg.file(ETH_B, "xlip", address(0));
        ilkReg.file(ETH_C, "xlip", address(0));
        vm.stopPrank();

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenClipperMomIsNotWardInClip() public {
        uint256 before = vm.snapshotState();

        vm.prank(pauseProxy);
        clipA.deny(address(clipperMom));
        assertFalse(spell.done(), "ETH-A spell already done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        clipB.deny(address(clipperMom));
        assertFalse(spell.done(), "ETH-B spell already done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        clipC.deny(address(clipperMom));
        assertFalse(spell.done(), "ETH-C spell already done");
        vm.revertToState(before);

        vm.startPrank(pauseProxy);
        clipA.deny(address(clipperMom));
        clipB.deny(address(clipperMom));
        clipC.deny(address(clipperMom));
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
