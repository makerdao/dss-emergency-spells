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

interface DssMultiIlkEmergencySpellLike is DssEmergencySpellLike {
    function ilks() external view returns (bytes32[] memory);
}

/// @title Multi-ilk Emergency Spell
/// @notice Defines the base implementation for multi-ilk emergency spells.
/// @custom:authors [amusingaxl]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
abstract contract DssMultiIlkEmergencySpell is DssEmergencySpell, DssMultiIlkEmergencySpellLike {
    /// @dev The total number of ilks in the spell.
    uint256 internal immutable _totalIlks;
    /// @dev The 0th ilk to which the spell should be applicable.
    bytes32 internal immutable _ilk0;
    /// @dev The 1st ilk to which the spell should be applicable.
    bytes32 internal immutable _ilk1;
    /// @dev The 2nd ilk to which the spell should be applicable.
    bytes32 internal immutable _ilk2;
    /// @dev The min size for the list of ilks
    uint256 internal constant MIN_LIST_SIZE = 2;
    /// @dev The max size for the list of ilks
    uint256 internal constant MAX_LIST_SIZE = 3;

    /// @param _ilks The list of ilks for which the spell should be applicable
    /// @dev The list size is be at least 2 and less than or equal to 3.
    ///      The multi-ilk spell is meant to be used for ilks that are a variation of tha same collateral gem
    ///      (i.e.: ETH-A, ETH-B, ETH-C)
    ///      There has never been a case where MCD onboarded 4 or more ilks for the same collateral gem.
    ///      For cases where there is only one ilk for the same collateral gem, use the single-ilk version.
    constructor(bytes32[] memory _ilks) {
        // This is a workaround to Solidity's lack of ability to support immutable arrays, as described in
        // https://github.com/ethereum/solidity/issues/12587
        uint256 len = _ilks.length;
        require(len >= MIN_LIST_SIZE, "DssMultiIlkEmergencySpell/too-few-ilks");
        require(len <= MAX_LIST_SIZE, "DssMultiIlkEmergencySpell/too-many-ilks");
        _totalIlks = len;

        _ilk0 = _ilks[0];
        _ilk1 = _ilks[1];
        // Only ilk2 is not guaranteed to exist.
        _ilk2 = len > 2 ? _ilks[2] : bytes32(0);
    }

    /// @notice Returns the list of ilks to which the spell is applicable.
    /// @return _ilks The list of ilks
    function ilks() public view returns (bytes32[] memory _ilks) {
        _ilks = new bytes32[](_totalIlks);
        _ilks[0] = _ilk0;
        _ilks[1] = _ilk1;
        if (_totalIlks > 2) {
            _ilks[2] = _ilk2;
        }
    }

    /// @notice Returns the spell description.
    function description() external view returns (string memory) {
        // Join the list of ilks into a comma-separated string
        string memory buf = string.concat(_bytes32ToString(_ilk0), ", ", _bytes32ToString(_ilk1));
        if (_totalIlks > 2) {
            buf = string.concat(buf, ", ", _bytes32ToString(_ilk2));
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
    function _descriptionPrefix() internal virtual view returns (string memory);


    /// @inheritdoc DssEmergencySpell
    function _emergencyActions() internal override {
        _emergencyActions(_ilk0);
        _emergencyActions(_ilk1);
        if (_totalIlks > 2) {
            _emergencyActions(_ilk2);
        }
    }

    /// @notice Executes the emergency actions for the specified ilk.
    /// @param _ilk The ilk to set the related Clip breaker.
    function _emergencyActions(bytes32 _ilk) internal virtual;

    /// @notice Returns whether the spell is done for all ilks or not.
    /// @dev Checks if all Clip instances have stopped = 3.
    ///      The spell would revert if any of the following conditions holds:
    ///          1. Clip is set to address(0)
    ///          2. ClipperMom is not a ward on Clip
    ///          3. Clip does not implement the `stopped` function
    ///      In such cases, it returns `true`, meaning no further action can be taken at the moment.
    /// @return res Whether the spells is done or not.
    function done() external view returns (bool res) {
        res = _done(_ilk0) && _done(_ilk1);
        if (_totalIlks > 2) {
            res = res && _done(_ilk2);
        }
    }

    /// @notice Returns whether the spell is done or not for the specified ilk.
    function _done(bytes32 _ilk) internal virtual view returns (bool);
}
