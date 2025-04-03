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

interface BeamMomLike {
    function halt(address) external;
}

interface BeamLike {
    function wards(address) external view returns (uint256);
    function bad() external view returns (uint256);
}

/// @title BEAM Halt Emergency Spell
/// @notice Will disable a BEAM (Bounded External Access Module)
contract SingleBeamHaltSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | Halt BEAM";

    BeamMomLike public immutable beamMom;
    BeamLike public immutable beam;

    event Halt();

    /**
     * @notice constructor
     * @param _beamMom The address of the BEAMMom contract
     * @param _beam The address of the BEAM contract
     */
    constructor(address _beamMom, address _beam) {
        beamMom = BeamMomLike(_beamMom);
        beam = BeamLike(_beam);
    }

    /**
     * @notice Disables BEAM
     */
    function _emergencyActions() internal override {
        beamMom.halt(address(beam));
        emit Halt();
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if `beam.bad() == 1` (disabled).
     *      The spell would revert if any of the following conditions holds:
     *          1. BEAMMom is not a ward of BEAM
     *          2. Call to BEAM `hop()` reverts (likely not a BEAM)
     *      In both cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        try beam.wards(address(beamMom)) returns (uint256 ward) {
            // Ignore BEAM instances that have not relied on BEAMMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a BEAM instance.
            return true;
        }

        try beam.bad() returns (uint256 bad) {
            return bad == 1;
        } catch {
            // If the call failed, it means the contract is most likely not a BEAM instance.
            return true;
        }
    }
}

contract SingleBeamHaltFactory {
    event Deploy(address beam, address spell);
    address public immutable beamMom;

    constructor(address _beamMom) {
        beamMom = _beamMom;
    }

    function deploy(address beam) external returns (address spell) {
        spell = address(new SingleBeamHaltSpell(beamMom, beam));
        emit Deploy(beam, spell);
    }
}

