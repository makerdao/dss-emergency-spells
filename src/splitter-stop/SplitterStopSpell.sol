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
    function hop() external view returns (uint256);
}

/// @title Splitter Stop Emergency Spell
/// @notice Will disable the Splitter (Smart Burn Engine, former Flap auctions)
/// @custom:authors [Oddaf]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract SplitterStopSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | Disable Splitter";

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
     */
    function done() external view returns (bool) {
        return splitter.hop() == type(uint256).max;
    }
}
