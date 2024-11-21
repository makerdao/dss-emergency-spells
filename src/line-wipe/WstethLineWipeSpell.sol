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

interface LineMomLike {
    function autoLine() external view returns (address);
    function ilks(bytes32 ilk) external view returns (uint256);
    function wipe(bytes32 ilk) external returns (uint256);
}

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
    function wards(address who) external view returns (uint256);
}

interface VatLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
    function wards(address who) external view returns (uint256);
}

contract WstethLineWipeSpell is DssEmergencySpell {
    LineMomLike public immutable lineMom = LineMomLike(_log.getAddress("LINE_MOM"));
    AutoLineLike public immutable autoLine = AutoLineLike(LineMomLike(_log.getAddress("LINE_MOM")).autoLine());
    VatLike public immutable vat = VatLike(_log.getAddress("MCD_VAT"));
    bytes32 internal constant WSTETH_A = "WSTETH-A";
    bytes32 internal constant WSTETH_B = "WSTETH-B";
    string public constant description =
        string(abi.encodePacked("Emergency Spell | Line Wipe: ", WSTETH_A, ", ", WSTETH_B));

    event Wipe(bytes32 indexed ilk);

    function _emergencyActions() internal override {
        lineMom.wipe(WSTETH_A);
        lineMom.wipe(WSTETH_B);

        emit Wipe(WSTETH_A);
        emit Wipe(WSTETH_B);
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the ilks have been wiped from auto-line and/or vat line is zero.
     *      The spell would revert if any of the following conditions holds:
     *          1. LineMom is not ward on Vat
     *          2. LineMom is not ward on AutoLine
     *          3. The ilk has not been added to LineMom
     *      In such cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        return _done(WSTETH_A) && _done(WSTETH_B);
    }

    /**
     * @notice Returns whether the spell is done or not for the specified ilk.
     */
    function _done(bytes32 _ilk) internal view returns (bool) {
        if (vat.wards(address(lineMom)) == 0 || autoLine.wards(address(lineMom)) == 0 || lineMom.ilks(_ilk) == 0) {
            return true;
        }

        (,,, uint256 line,) = vat.ilks(_ilk);
        (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(_ilk);

        return line == 0 && maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0;
    }
}
