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

enum Flow {
    SELL, // Halt only selling gems
    BUY, // Halt only buying gems
    BOTH // Halt both
}

interface LitePsmMomLike {
    function halt(address psm, Flow what) external;
}

interface LitePsmLike {
    function tin() external view returns (uint256);
    function tout() external view returns (uint256);
    function HALTED() external view returns (uint256);
}

/// @title Lite PSM Halt Emergency Spell
/// @notice Will halt trading on MCD_LITE_PSM_USDC_A, can halt only gem buys, sells, or both.
/// @custom:authors [Oddaf]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract SingleLitePsmHaltSpell is DssEmergencySpell {
    LitePsmMomLike public immutable litePsmMom = LitePsmMomLike(_log.getAddress("LITE_PSM_MOM"));
    address public immutable psm;
    Flow public immutable flow;

    event Halt(Flow what);

    constructor(address _psm, Flow _flow) {
        psm = _psm;
        flow = _flow;
    }

    function _flowToString(Flow _flow) internal pure returns (string memory) {
        if (_flow == Flow.SELL) return "SELL";
        if (_flow == Flow.BUY) return "BUY";
        if (_flow == Flow.BOTH) return "BOTH";
        return "";
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | MCD_LITE_PSM_USDC_A halt: ", _flowToString(flow)));
    }

    /**
     * @notice Halts trading on LitePSM
     */
    function _emergencyActions() internal override {
        litePsmMom.halt(psm, flow);
        emit Halt(flow);
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the swaps have been halted on the psm.
     */
    function done() external view returns (bool) {
        uint256 halted = LitePsmLike(psm).HALTED();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            if (LitePsmLike(psm).tin() != halted) return false;
        }

        if (flow == Flow.BUY || flow == Flow.BOTH) {
            if (LitePsmLike(psm).tout() != halted) return false;
        }

        return true;
    }
}

contract SingleLitePsmHaltSpellFactory {
    event Deploy(address psm, Flow indexed flow, address spell);

    function deploy(address psm, Flow flow) external returns (address spell) {
        spell = address(new SingleLitePsmHaltSpell(psm, flow));
        emit Deploy(psm, flow, spell);
    }
}
