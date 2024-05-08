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


interface WardsLike {
    function wards(address who) external view returns (uint256);
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
    DssEmergencySpellLike spell;

    mapping(bytes32 => bool) ilksToIgnore;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        osmMom = OsmMomLike(dss.chainlog.getAddress("OSM_MOM"));
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        spell = new UniversalOsmStopSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        _initIlksToIgnore();

        vm.makePersistent(chief);
    }

    /// @dev Ignore any of:
    function _initIlksToIgnore() internal {
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            string memory ilkStr = string(abi.encodePacked(ilks[i]));
            address osm = ilkReg.pip(ilks[i]);
            if (osm == address(0)) {
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | No OSM", ilkStr);
                continue;
            }

            try OsmLike(osm).stopped() returns (uint256 stopped) {
                if (stopped == 1) {
                    ilksToIgnore[ilks[i]] = true;
                    emit log_named_string("Ignoring ilk | OSM already stopped", ilkStr);
                    continue;
                }
            } catch {
                // Most likely not an OSM instance.
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | Not an OSM", ilkStr);
                continue;
            }

            try WardsLike(osm).wards(address(osmMom)) returns (uint256 ward) {
                if (ward == 0) {
                    ilksToIgnore[ilks[i]] = true;
                    emit log_named_string("Ignoring ilk | OsmMom not authorized", ilkStr);
                    continue;
                }
            } catch {
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | Not an OSM", ilkStr);
                continue;
            }
        }
    }

    function testUniversalOracleStopOnSchedule() public {
        _checkAllOsmStoppedStatus({expected: 0});

        spell.schedule();

        _checkAllOsmStoppedStatus({expected: 1});
    }

    function testUnauthorizedOsmMomShouldNotRevert() public {
        address pipEth = ilkReg.pip("ETH-A");
        // De-auth OsmMom to force the error:
        stdstore.target(pipEth).sig("wards(address)").with_key(address(osmMom)).checked_write(bytes32(0));
        // Updates the list of ilks to be ignored.
        _initIlksToIgnore();

        _checkAllOsmStoppedStatus({expected: 0});

        DssEmergencySpellLike(spell).schedule();

        _checkAllOsmStoppedStatus({expected: 1});
        assertEq(OsmLike(pipEth).stopped(), 0, "ETH-A pip was not ignored");
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
            if (ilksToIgnore[ilks[i]]) continue;

            address pip = ilkReg.pip(ilks[i]);
            assertEq(OsmLike(pip).stopped(), expected, string(abi.encodePacked("invalid stopped status: ", ilks[i])));
        }
    }
}