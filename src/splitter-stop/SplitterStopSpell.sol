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

interface SplitterMomLike {
    function stop() external;
}

interface SplitterLike {
    function wards(address) external view returns (uint256);
    function hop() external view returns (uint256);
}

/// @title Splitter Stop Emergency Spell
/// @notice Disables the Splitter (Smart Burn Engine, former Flap auctions)
/// @custom:authors [oddaf]
/// @custom:reviewers [amusingaxl]
/// @custom:auditors []
/// @custom:bounties []
contract SplitterStopSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | Stop Splitter";

    SplitterMomLike public immutable splitterMom = SplitterMomLike(_log.getAddress("SPLITTER_MOM"));
    SplitterLike public immutable splitter = SplitterLike(_log.getAddress("MCD_SPLIT"));

    event Stop();

    /**
     * @notice Disables Splitter
     */
    function _emergencyActions() internal override {
        splitterMom.stop();
        emit Stop();
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if `splitter.hop() == type(uint).max` (disabled).
     *      The spell would revert if any of the following conditions holds:
     *          1. SplitterMom is not a ward of Splitter
     *          2. Call to Splitter `hop()` reverts (likely not a Splitter)
     *      In both cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        try splitter.wards(address(splitterMom)) returns (uint256 ward) {
            // Ignore Splitter instances that have not relied on SplitterMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a Splitter instance.
            return true;
        }

        try splitter.hop() returns (uint256 hop) {
            return hop == type(uint256).max;
        } catch {
            // If the call failed, it means the contract is most likely not a Splitter instance.
            return true;
        }
    }
}
