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
import {UniversalOsmStopSpell} from "./UniversalOsmStopSpell.sol";

interface OsmMomLike {
    function osms(bytes32) external view returns (address);
}

interface OsmLike {
    function stopped() external view returns (uint256);
    function osms(bytes32 ilk) external view returns (address);
}

interface IlkRegistryLike {
    function list() external view returns (bytes32[] memory);
    function pip(bytes32 ilk) external view returns (address);
}

contract UniversalOsmStopSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    OsmMomLike osmMom;
    IlkRegistryLike ilkReg;
    OsmLike osm;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        osmMom = OsmMomLike(dss.chainlog.getAddress("OSM_MOM"));
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        spell = new UniversalOsmStopSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testUniversalOracleStopOnSchedule() public {
        _checkAllOsmStoppedStatus({expected: 0});

        spell.schedule();

        _checkAllOsmStoppedStatus({expected: 1});
    }

    function testRevertUniversalOracleStopWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        _checkAllOsmStoppedStatus({expected: 0});

        vm.expectRevert();
        spell.schedule();

        _checkAllOsmStoppedStatus({expected: 0});
    }

    function _checkAllOsmStoppedStatus(uint256 expected) internal view {
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            if (osmMom.osms(ilks[i]) != address(0)) {
                OsmLike pip = OsmLike(ilkReg.pip(ilks[i]));
                try pip.stopped() returns (uint256 stopped) {
                    assertEq(stopped, expected, string(abi.encodePacked("invalid stopped state: ", ilks[i])));
                } catch {
                    // Most likely not an OSM.
                }
            }
        }
    }
}
