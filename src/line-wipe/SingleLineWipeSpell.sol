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

contract SingleLineWipeSpell is DssEmergencySpell {
    LineMomLike public immutable lineMom = LineMomLike(_log.getAddress("LINE_MOM"));
    AutoLineLike public immutable autoLine = AutoLineLike(LineMomLike(_log.getAddress("LINE_MOM")).autoLine());
    VatLike public immutable vat = VatLike(_log.getAddress("MCD_VAT"));
    bytes32 public immutable ilk;

    event Wipe();

    constructor(bytes32 _ilk) {
        ilk = _ilk;
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | Line Wipe: ", ilk));
    }

    function _emergencyActions() internal override {
        lineMom.wipe(ilk);
        emit Wipe();
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the ilk has been wiped from auto-line and/or vat line is zero.
     *      The spell would revert if any of the following conditions holds:
     *          1. LineMom is not ward on Vat
     *          2. LineMom is not ward on AutoLine
     *          3. The ilk has not been added to LineMom
     *      In such cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        if (vat.wards(address(lineMom)) == 0 || autoLine.wards(address(lineMom)) == 0 || lineMom.ilks(ilk) == 0) {
            return true;
        }

        (,,, uint256 line,) = vat.ilks(ilk);
        (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(ilk);

        return line == 0 && maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0;
    }
}

contract SingleLineWipeFactory {
    event Deploy(bytes32 indexed ilk, address spell);

    function deploy(bytes32 ilk) external returns (address spell) {
        spell = address(new SingleLineWipeSpell(ilk));
        emit Deploy(ilk, spell);
    }
}
