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

interface ChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface DssEmergencySpellLike {
    function action() external view returns (address);
    function cast() external;
    function description() external view returns (string memory);
    function done() external view returns (bool);
    function eta() external view returns (uint256);
    function expiration() external view returns (uint256);
    function log() external view returns (address);
    function nextCastTime() external view returns (uint256);
    function officeHours() external view returns (bool);
    function pause() external view returns (address);
    function schedule() external;
    function sig() external view returns (bytes memory);
    function tag() external view returns (bytes32);
}

abstract contract DssEmergencySpell is DssEmergencySpellLike {
    ChainlogLike internal constant _log = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    address public constant log = address(_log);
    uint256 public constant eta = 0;
    bytes public constant sig = "";
    uint256 public constant expiration = type(uint256).max;
    // @notice Office Hours is always `false` for emergency spells.
    bool public constant officeHours = false;
    address public immutable action = address(this);
    bytes32 public immutable tag = keccak256(abi.encodePacked(address(this)));
    address public immutable pause = ChainlogLike(log).getAddress("MCD_PAUSE");
    uint256 public immutable nextCastTime = block.timestamp;


    /**
     * @notice Triggers the emergency actions of the spell.
     * @dev Emergency spells are triggered when scheduled.
     *      This function maintains the name for compatibility with regular spells, however nothing is actually being
     *      scheduled. Emergency spell take affect immediately, so there is no need to call `pause.plot()`.
     */
    function schedule() external {
        _emeregencyActions();
    }

    /**
     * @notice No-op.
     * @dev this function exists only to keep interface compatibility with regular spells.
     */
    function cast() external {}

    /**
     * @notice Implements the emergency actions to be triggered by the spell.
     */
    function _emeregencyActions() internal virtual;

}
