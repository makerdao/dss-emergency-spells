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

import {DssEmergencySpell, DssEmergencySpellLike} from "./DssEmergencySpell.sol";

interface DssGroupedEmergencySpellLike is DssEmergencySpellLike {
    function ilks() external view returns (bytes32[] memory);
    function emergencyActionsInBatch(uint256 start, uint256 end) external;
}

/// @title Grouped Emergency Spell
/// @notice Defines the base implementation for grouped emergency spells.
/// @custom:authors [amusingaxl]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
abstract contract DssGroupedEmergencySpell is DssEmergencySpell, DssGroupedEmergencySpellLike {
    /// @dev The min size for the list of ilks
    uint256 private constant MIN_ILKS = 1;

    /// @notice The list of ilks to which the spell is applicable.
    /// @dev While spells should not have storage variables, we can make an exception here because this spell should not
    ///      change its own storage, and therefore, could not overwrite the PauseProxy state through delegate call even
    ///      if used incorrectly.
    bytes32[] private ilkList;

    /// @param _ilks The list of ilks for which the spell should be applicable
    /// @dev The list size must be at least 1.
    ///      The grouped spell is meant to be used for ilks that are a variation of the same collateral gem
    ///      (i.e.: ETH-A, ETH-B, ETH-C)
    ///      There has never been a case where MCD onboarded 4 or more ilks for the same collateral gem.
    ///      For cases where there is only one ilk for the same collateral gem, use the single-ilk version.
    constructor(bytes32[] memory _ilks) {
        // This is a workaround to Solidity's lack of support for immutable arrays, as described in
        // https://github.com/ethereum/solidity/issues/12587
        uint256 len = _ilks.length;
        require(len >= MIN_ILKS, "DssGroupedEmergencySpell/too-few-ilks");

        ilkList = _ilks;
    }

    /// @notice Returns the list of ilks to which the spell is applicable.
    function ilks() external view returns (bytes32[] memory) {
        return ilkList;
    }

    /// @notice Returns the spell description.
    function description() external view returns (string memory) {
        // Join the list of ilks into a comma-separated string
        string memory buf = _bytes32ToString(ilkList[0]);
        // Start from one because the first item was already added.
        for (uint256 i = 1; i < ilkList.length; i++) {
            buf = string.concat(buf, ", ", _bytes32ToString(ilkList[i]));
        }

        return string.concat(_descriptionPrefix(), " ", buf);
    }

    /// @notice Converts a bytes32 value into a string.
    function _bytes32ToString(bytes32 src) internal pure returns (string memory res) {
        uint256 len = 0;
        while (src[len] != 0 && len < 32) {
            len++;
        }
        assembly {
            res := mload(0x40)
            // new "memory end" including padding (the string isn't larger than 32 bytes)
            mstore(0x40, add(res, 0x40))
            // store len in memory
            mstore(res, len)
            // write actual data
            mstore(add(res, 0x20), src)
        }
    }

    /// @dev Returns the description prefix to compose the final description.
    function _descriptionPrefix() internal view virtual returns (string memory);

    /// @inheritdoc DssEmergencySpell
    function _emergencyActions() internal override {
        for (uint256 i = 0; i < ilkList.length; i++) {
            _emergencyActions(ilkList[i]);
        }
    }

    /// @notice Executes the emergency actions for all ilks in the batch.
    /// @dev This is an escape hatch to prevent the spell from being blocked in case it would hit the block gas limit.
    ///      In case `end` is greater than the ilk list length, the iteration will be automatically capped.
    /// @param start The index to start the iteration (inclusive).
    /// @param end The index to stop the iteration (inclusive).
    function emergencyActionsInBatch(uint256 start, uint256 end) external {
        end = end > ilkList.length - 1 ? ilkList.length - 1 : end;
        require(start <= end, "DssGroupedEmergencySpell/bad-iteration");

        for (uint256 i = start; i <= end; i++) {
            _emergencyActions(ilkList[i]);
        }
    }

    /// @notice Executes the emergency actions for the specified ilk.
    /// @param _ilk The ilk upon which to execute the emergency actions.
    function _emergencyActions(bytes32 _ilk) internal virtual;

    /// @notice Returns whether the spell is done for all ilks or not.
    /// @return res Whether the spells is done or not.
    function done() external view returns (bool res) {
        for (uint256 i = 0; i < ilkList.length; i++) {
            if (!_done(ilkList[i])) {
                return false;
            }
        }
        return true;
    }

    /// @notice Returns whether the spell is done or not for the specified ilk.
    function _done(bytes32 _ilk) internal view virtual returns (bool);
}
