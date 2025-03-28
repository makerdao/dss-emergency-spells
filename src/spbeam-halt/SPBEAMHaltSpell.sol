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

interface SPBEAMMomLike {
    function halt(address) external;
}

interface SPBEAMLike {
    function wards(address) external view returns (uint256);
    function bad() external view returns (uint256);
}

/// @title SP-BEAM Halt Emergency Spell
/// @notice Will disable the SPBEAM (Stability Parameter Bounded External Access Module)
contract SPBEAMHaltSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | Halt SPBEAM";

    SPBEAMMomLike public immutable spbeamMom = SPBEAMMomLike(_log.getAddress("SPBEAM_MOM"));
    SPBEAMLike public immutable spbeam = SPBEAMLike(_log.getAddress("MCD_SP_BEAM"));

    event Halt();

    /**
     * @notice Disables SPBEAM
     */
    function _emergencyActions() internal override {
        spbeamMom.halt(address(spbeam));
        emit Halt();
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if `spbeam.bad() == 1` (disabled).
     *      The spell would revert if any of the following conditions holds:
     *          1. SPBEAMMom is not a ward of SPBEAM
     *          2. Call to SPBEAM `hop()` reverts (likely not a SPBEAM)
     *      In both cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        try spbeam.wards(address(spbeamMom)) returns (uint256 ward) {
            // Ignore SPBEAM instances that have not relied on SPBEAMMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a SPBEAM instance.
            return true;
        }

        try spbeam.bad() returns (uint256 bad) {
            return bad == 1;
        } catch {
            // If the call failed, it means the contract is most likely not a SPBEAM instance.
            return true;
        }
    }
}
