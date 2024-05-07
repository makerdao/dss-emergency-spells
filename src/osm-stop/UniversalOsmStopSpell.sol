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

import {DssEmergencySpell} from "../DssEmergencySpell.sol";

interface OsmMomLike {
    function stop(bytes32 ilk) external;
    function osms(bytes32 ilk) external view returns (address);
}

interface IlkRegistryLike {
    function list() external view returns (bytes32[] memory);
}

contract UniversalOsmStopSpell is DssEmergencySpell {
    OsmMomLike public immutable osmMom = OsmMomLike(_log.getAddress("OSM_MOM"));
    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));

    string public constant override description = "Emergency Spell | Universal OSM Stop";

    event Stop(bytes32 ilk);

    constructor()
        // In practice, this spell would never expire
        DssEmergencySpell(type(uint256).max)
    {}

    function _onSchedule() internal override {
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            if (osmMom.osms(ilks[i]) != address(0)) {
                // There might be some duplicate calls to the same OSM, however they are idempotent.
                try OsmMomLike(osmMom).stop(ilks[i]) {
                    emit Stop(ilks[i]);
                } catch Error(string memory reason) {
                    // Ignore any failing calls to `osmMom.stop` with no error being returned.
                    require(bytes(reason).length == 0, reason);
                }
            }
        }
    }
}
