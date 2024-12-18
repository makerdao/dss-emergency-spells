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

import {DssGroupedEmergencySpell} from "../DssGroupedEmergencySpell.sol";

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

/// @title Emergency Spell: Grouped Clip Breaker
/// @notice Prevents further collateral auctions to be held in the respective Clip contracts.
/// @custom:authors [amusingaxl]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract GroupedClipBreakerSpell is DssGroupedEmergencySpell {
    /// @notice The ClipperMom from chainlog.
    ClipperMomLike public immutable clipperMom = ClipperMomLike(_log.getAddress("CLIPPER_MOM"));
    /// @notice The IlkRegistry from chainlog.
    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));

    /// @dev During an emergency, set the breaker level to 3 to prevent `kick()`, `redo()` and `take()`.
    uint256 internal constant BREAKER_LEVEL = 3;
    /// @dev The delay is not applicable for level 3 breakers, so we set it to zero.
    uint256 internal constant BREAKER_DELAY = 0;

    /// @notice Emitted when the spell is scheduled.
    /// @param ilk The ilk for which the Clip breaker was set.
    /// @param clip The address of the Clip contract.
    event SetBreaker(bytes32 indexed ilk, address indexed clip);

    /// @param _ilks The list of ilks for which the spell should be applicable
    /// @dev The list size is be at least 1.
    ///      The grouped spell is meant to be used for ilks that are a variation of the same collateral gem
    ///      (i.e.: ETH-A, ETH-B, ETH-C)
    constructor(bytes32[] memory _ilks) DssGroupedEmergencySpell(_ilks) {}

    /// @inheritdoc DssGroupedEmergencySpell
    function _descriptionPrefix() internal pure override returns (string memory) {
        return "Emergency Spell | Grouped Clip Breaker:";
    }

    /// @notice Sets the breaker for the related Clip contract.
    /// @inheritdoc DssGroupedEmergencySpell
    function _emergencyActions(bytes32 _ilk) internal override {
        address clip = ilkReg.xlip(_ilk);
        clipperMom.setBreaker(clip, BREAKER_LEVEL, BREAKER_DELAY);
        emit SetBreaker(_ilk, clip);
    }

    /// @notice Returns whether the spell is done or not for the specified ilk.
    function _done(bytes32 _ilk) internal view override returns (bool) {
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

/// @title Emergency Spell Factory: Grouped Clip Breaker
/// @notice On-chain factory to deploy Grouped Clip Breaker emergency spells.
/// @custom:authors [amusingaxl]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract GroupedClipBreakerFactory {
    /// @notice A new GroupedClipBreakerSpell has been deployed.
    /// @param ilks The list of ilks for which the spell is applicable.
    /// @param spell The deployed spell address.
    event Deploy(bytes32[] indexed ilks, address spell);

    /// @notice Deploys a GroupedClipBreakerSpell contract.
    /// @param ilks The list of ilks for which the spell is applicable.
    function deploy(bytes32[] memory ilks) external returns (address spell) {
        spell = address(new GroupedClipBreakerSpell(ilks));
        emit Deploy(ilks, spell);
    }
}
