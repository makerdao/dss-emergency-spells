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

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
    function xlip(bytes32 ilk) external view returns (address);
}

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface WardsLike {
    function wards(address who) external view returns (uint256);
}

contract UniversalClipBreakerSpell is DssEmergencySpell {
    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));
    ClipperMomLike public immutable clipperMom = ClipperMomLike(_log.getAddress("CLIPPER_MOM"));

    string public constant override description = "Emergency Spell | Universal Clip Breaker";

    uint256 public constant BREAKER_LEVEL = 3;
    // For level 3 breakers, the delay is not applicable, so we set it to zero.
    uint256 public constant BREAKER_DELAY = 0;

    event SetBreaker(bytes32 indexed ilk, address indexed clip);

    /**
     * @notice Set breakers, when possible, for all Clip instances that can be found in the ilk registry.
     */
    function _emeregencyActions() internal override {
        bytes32[] memory ilks = ilkReg.list();
        _doSetBreaker(ilks);
    }

    /**
     * @notice Set breakers for all Clips in the batch.
     * @dev This is an escape hatch to prevent this spell from being blocked in case it would hit the block gas limit.
     *      In case `end` is greater than the ilk registry length, the iteration will be automatically capped.
     * @param start The index to start the iteration (inclusive).
     * @param end The index to stop the iteration (inclusive).
     */
    function setBreakerInBatch(uint256 start, uint256 end) external {
        uint256 maxEnd = ilkReg.count() - 1;
        bytes32[] memory ilks = ilkReg.list(start, end < maxEnd ? end : maxEnd);
        _doSetBreaker(ilks);
    }

    /**
     * @notice Set breakers, when possible, for all Clip instances that can be found from the `ilks` list.
     * @param ilks The list of ilks to consider.
     */
    function _doSetBreaker(bytes32[] memory ilks) internal {
        for (uint256 i = 0; i < ilks.length; i++) {
            bytes32 ilk = ilks[i];
            address clip = ilkReg.xlip(ilk);

            if (clip == address(0)) continue;

            try WardsLike(clip).wards(address(clipperMom)) returns (uint256 ward) {
                // Ignore Clip instances that have not relied on ClipperMom.
                if (ward != 1) continue;
            } catch Error(string memory reason) {
                // If the reason is empty, it means the contract is most likely not a Clip instance.
                require(bytes(reason).length == 0, reason);
            }

            try clipperMom.setBreaker(clip, BREAKER_LEVEL, BREAKER_DELAY) {
                emit SetBreaker(ilk, clip);
            } catch Error(string memory reason) {
                // Ignore any failing calls to `clipeprMom.setBreaker` with no revert reason.
                require(bytes(reason).length == 0, reason);
            }
        }
    }
}
