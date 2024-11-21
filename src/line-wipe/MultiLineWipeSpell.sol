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

/// @title Emergency Spell: Multi Line Wipe
/// @notice Prevents further debt from being generated for the specified ilks.
/// @custom:authors [amusingaxl]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract MultiLineWipeSpell is DssEmergencySpell {
    /// @notice The LineMom from chainlog.
    LineMomLike public immutable lineMom = LineMomLike(_log.getAddress("LINE_MOM"));
    /// @notice The AutoLine IAM.
    AutoLineLike public immutable autoLine = AutoLineLike(LineMomLike(_log.getAddress("LINE_MOM")).autoLine());
    /// @notice The Vat from chainlog.
    VatLike public immutable vat = VatLike(_log.getAddress("MCD_VAT"));

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

    /// @notice Emitted when the spell is scheduled.
    /// @param ilk The ilk for which the Clip breaker was set.
    event Wipe(bytes32 indexed ilk);

    /// @param _ilks The list of ilks for which the spell should be applicable
    /// @dev The list size is be at least 2 and less than or equal to 3.
    ///      The multi-ilk spell is meant to be used for ilks that are a variation of tha same collateral gem
    ///      (i.e.: ETH-A, ETH-B, ETH-C)
    ///      There has never been a case where MCD onboarded 4 or more ilks for the same collateral gem.
    ///      For cases where there is only one ilk for the same collateral gem, use the single-ilk version.
    constructor(bytes32[] memory _ilks) {
        // This is a workaround to Solidity's lack of ability to support immutable arrays, as described in
        // https://github.com/ethereum/solidity/issues/12587
        uint256 listSize = _ilks.length;
        require(listSize >= MIN_LIST_SIZE, "MultiLineWipeSpell/too-few-ilks");
        require(listSize <= MAX_LIST_SIZE, "MultiLineWipeSpell/too-many-ilks");
        _totalIlks = listSize;

        _ilk0 = _ilks[0];
        _ilk1 = _ilks[1];
        // Only ilk2 is not guaranteed to exist.
        _ilk2 = listSize > 2 ? _ilks[2] : bytes32(0);
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

    /// @notice Returns the spell description.
    function description() external view returns (string memory) {
        // Join the list of ilks into a comma-separated string
        string memory buf = string.concat(_bytes32ToString(_ilk0), ", ", _bytes32ToString(_ilk1));
        if (_totalIlks > 2) {
            buf = string.concat(buf, ", ", _bytes32ToString(_ilk2));
        }

        return string.concat("Emergency Spell | Multi Line Wipe: ", buf);
    }

    /// @inheritdoc DssEmergencySpell
    function _emergencyActions() internal override {
        _wipe(_ilk0);
        _wipe(_ilk1);
        if (_totalIlks > 2) {
            _wipe(_ilk2);
        }
    }

    /// @notice Wipes the line for the specified ilk..
    /// @param _ilk The ilk to be wiped.
    function _wipe(bytes32 _ilk) internal {
        lineMom.wipe(_ilk);
        emit Wipe(_ilk);
    }

    /// @notice Returns whether the spell is done or not.
    /// @dev Checks if the ilks have been wiped from auto-line and/or vat line is zero.
    ///      The spell would revert if any of the following conditions holds:
    ///          1. LineMom is not ward on Vat
    ///          2. LineMom is not ward on AutoLine
    ///          3. The ilk has not been added to LineMom
    ///      In such cases, it returns `true`, meaning no further action can be taken at the moment.
    /// @return res Whether the spells is done or not.
    function done() external view returns (bool res) {
        res = _done(_ilk0) && _done(_ilk1);
        if (_totalIlks > 2) {
            res = res && _done(_ilk2);
        }
    }

    /// @notice Returns whether the spell is done or not for the specified ilk.
    function _done(bytes32 _ilk) internal view returns (bool) {
        if (vat.wards(address(lineMom)) == 0 || autoLine.wards(address(lineMom)) == 0 || lineMom.ilks(_ilk) == 0) {
            return true;
        }

        (,,, uint256 line,) = vat.ilks(_ilk);
        (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(_ilk);

        return line == 0 && maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0;
    }
}

/// @title Emergency Spell Factory: Multi Line Wipe
/// @notice On-chain factory to deploy Multi Line Wipe emergency spells.
/// @custom:authors [amusingaxl]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract MultiLineWipeFactory {
    /// @notice A new MultiLineWipeSpell has been deployed.
    /// @param ilks The list of ilks for which the spell is applicable.
    /// @param spell The deployed spell address.
    event Deploy(bytes32[] indexed ilks, address spell);

    /// @notice Deploys a MultiLineWipeSpell contract.
    /// @param ilks The list of ilks for which the spell is applicable.
    function deploy(bytes32[] memory ilks) external returns (address spell) {
        spell = address(new MultiLineWipeSpell(ilks));
        emit Deploy(ilks, spell);
    }
}
