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
import {DssEmergencySpellLike} from "../DssEmergencySpell.sol";
import {SingleOsmStopSpell} from "./SingleOsmStopSpell.sol";

interface OsmMomLike {
    function osms(bytes32) external view returns (address);
}

interface OsmLike {
    function stopped() external view returns (uint256);
}

contract SingleOsmStopTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    bytes32 ilk = "ETH-A";
    OsmMomLike osmMom;
    OsmLike osm;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        osmMom = OsmMomLike(dss.chainlog.getAddress("OSM_MOM"));
        osm = OsmLike(osmMom.osms(ilk));
        spell = new SingleOsmStopSpell(ilk);

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testOracleStopOnSchedule() public {
        assertEq(osm.stopped(), 0, "before: oracle already frozen");

        vm.expectEmit(true, true, true, true);
        emit Stop(address(osm));
        spell.schedule();

        assertEq(osm.stopped(), 1, "after: oracle not frozen");
    }

    function testRevertOracleStopWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        assertEq(osm.stopped(), 0, "before: oracle already frozen");

        vm.expectRevert();
        spell.schedule();

        assertEq(osm.stopped(), 0, "after: oracle frozen unexpectedly");
    }

    event Stop(address indexed osm);
}
