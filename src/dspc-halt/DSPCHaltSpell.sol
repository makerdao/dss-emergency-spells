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

interface DSPCMomLike {
    function halt(address) external;
}

interface DSPCLike {
    function wards(address) external view returns (uint256);
    function bad() external view returns (uint256);
}

/// @title DSPC Halt Emergency Spell
/// @notice Will disable the DSPC (Direct Stability Parameters Change Module)
/// @custom:authors [Oddaf]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract DSPCHaltSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | Halt DSPC";

    DSPCMomLike public immutable dspcMom = DSPCMomLike(_log.getAddress("DSPC_MOM"));
    DSPCLike public immutable dspc = DSPCLike(_log.getAddress("MCD_DSPC"));

    event Halt();

    /**
     * @notice Disables DSPC
     */
    function _emergencyActions() internal override {
        dspcMom.halt(address(dspc));
        emit Halt();
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if `dspc.bad() == 1` (disabled).
     *      The spell would revert if any of the following conditions holds:
     *          1. DSPCMom is not a ward of DSPC
     *          2. Call to DSPC `hop()` reverts (likely not a DSPC)
     *      In both cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        try dspc.wards(address(dspcMom)) returns (uint256 ward) {
            // Ignore DSPC instances that have not relied on DSPCMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a DSPC instance.
            return true;
        }

        try dspc.bad() returns (uint256 bad) {
            return bad == 1;
        } catch {
            // If the call failed, it means the contract is most likely not a DSPC instance.
            return true;
        }
    }
}
