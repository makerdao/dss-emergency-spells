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

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface ClipLike {
    function stopped() external view returns (uint256);
    function wards(address who) external view returns (uint256);
}

interface IlkRegistryLike {
    function xlip(bytes32 ilk) external view returns (address);
}

contract WbtcClipBreakerSpell is DssEmergencySpell {
    /// @dev During an emergency, set the breaker level to 3 to prevent `kick()`, `redo()` and `take()`.
    uint256 public constant BREAKER_LEVEL = 3;
    /// @dev The delay is not applicable for level 3 breakers, so we set it to zero.
    uint256 public constant BREAKER_DELAY = 0;

    ClipperMomLike public immutable clipperMom = ClipperMomLike(_log.getAddress("CLIPPER_MOM"));
    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));
    bytes32 internal constant WBTC_A = "WBTC-A";
    bytes32 internal constant WBTC_B = "WBTC-B";
    bytes32 internal constant WBTC_C = "WBTC-C";
    string public constant description =
        string(abi.encodePacked("Emergency Spell | Set Clip Breaker: ", WBTC_A, ", ", WBTC_B, ", ", WBTC_C));

    event SetBreaker(bytes32 indexed ilk, address indexed clip);

    function _emergencyActions() internal override {
        _setBreaker(WBTC_A);
        _setBreaker(WBTC_B);
        _setBreaker(WBTC_C);
    }

    function _setBreaker(bytes32 _ilk) internal {
        address clip = ilkReg.xlip(_ilk);
        clipperMom.setBreaker(clip, BREAKER_LEVEL, BREAKER_DELAY);
        emit SetBreaker(_ilk, clip);
    }

    /**
     * @notice Returns whether the spell is done for all ilks or not.
     * @dev Checks if all Clip instances have stopped = 3.
     *      The spell would revert if any of the following conditions holds:
     *          1. Clip is set to address(0)
     *          2. ClipperMom is not a ward on Clip
     *          3. Clip does not implement the `stopped` function
     *      In such cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        return _done(WBTC_A) && _done(WBTC_B) && _done(WBTC_C);
    }

    /**
     * @notice Returns whether the spell is done or not for the specified ilk.
     */
    function _done(bytes32 _ilk) internal view returns (bool) {
        address clip = ilkReg.xlip(_ilk);
        if (clip == address(0)) {
            return true;
        }

        try ClipLike(clip).wards(address(clipperMom)) returns (uint256 ward) {
            // Ignore Clip instances that have not relied on ClipperMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a Clip instance.
            return true;
        }

        try ClipLike(clip).stopped() returns (uint256 stopped) {
            return stopped == BREAKER_LEVEL;
        } catch {
            // If the call failed, it means the contract is most likely not a Clip instance.
            return true;
        }
    }
}
