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
import {DssTest, DssInstance, MCD, GodMode} from "dss-test/DssTest.sol";
import {DssMultiIlkEmergencySpell} from "./DssMultiIlkEmergencySpell.sol";

contract DssMultiIlkEmergencySpellImpl is DssMultiIlkEmergencySpell {
    mapping(bytes32 => bool) internal _isDone;

    function setDone(bytes32 ilk, bool val) external {
        _isDone[ilk] = val;
    }

    function _descriptionPrefix() internal pure override returns (string memory) {
        return "Multi-Ilk Emergency Spell:";
    }

    event EmergencyAction(bytes32 indexed ilk);

    constructor(bytes32[] memory _ilks) DssMultiIlkEmergencySpell(_ilks) {}

    function _emergencyActions(bytes32 ilk) internal override {
        emit EmergencyAction(ilk);
    }

    function _done(bytes32 ilk) internal view override returns (bool) {
        return _isDone[ilk];
    }
}
contract DssMultiIlkEmergencySpellTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    DssMultiIlkEmergencySpellImpl spell2;
    DssMultiIlkEmergencySpellImpl spell3;
    address pause;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        pause = dss.chainlog.getAddress("MCD_PAUSE");

        bytes32[] memory ilks2 = new bytes32[](2);
        ilks2[0] = "WSTETH-A";
        ilks2[1] = "WSTETH-B";
        spell2 = new DssMultiIlkEmergencySpellImpl(ilks2);
        bytes32[] memory ilks3 = new bytes32[](3);
        ilks3[0] = "ETH-A";
        ilks3[1] = "ETH-B";
        ilks3[2] = "ETH-C";
        spell3 = new DssMultiIlkEmergencySpellImpl(ilks3);
    }

    function testDescription() public view {
        assertEq(spell2.description(), "Multi-Ilk Emergency Spell: WSTETH-A, WSTETH-B");
        assertEq(spell3.description(), "Multi-Ilk Emergency Spell: ETH-A, ETH-B, ETH-C");
    }

    function testEmergencyActions() public {
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WSTETH-A");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WSTETH-B");
        spell2.schedule();

        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-A");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-B");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-C");
        spell3.schedule();
    }

    function testDone() public {
        assertFalse(spell2.done(), "spell2 unexpectedly done");
        assertFalse(spell3.done(), "spell2 unexpectedly done");

        {
            // Tweak spell2 so it is considered done for WSTETH-A...
            spell2.setDone("WSTETH-A", true);
            // ... in this case it should still return false
            assertFalse(spell2.done(), "spell2 unexpectedly done");
            // Then set done for WSTETH-B...
            spell2.setDone("WSTETH-B", true);
            // ... new the spell must finally return true
            assertTrue(spell2.done(), "spell2 not done");
        }

        {
            // Tweak spell3 so it is considered done for ETH-A...
            spell3.setDone("ETH-A", true);
            // ... in this case it should still return false
            assertFalse(spell3.done(), "spell3 unexpectedly done");
            // Then set done for ETH-B...
            spell3.setDone("ETH-B", true);
            // ... it should still return false
            assertFalse(spell3.done(), "spell3 unexpectedly done");
            // Then set done for ETH-C...
            spell3.setDone("ETH-C", true);
            // ... new the spell must finally return true
            assertTrue(spell3.done(), "spell3 not done");
        }
    }

    event EmergencyAction(bytes32 indexed ilk);
}
