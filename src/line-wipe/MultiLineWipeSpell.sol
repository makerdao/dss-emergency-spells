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

import {DssMultiIlkEmergencySpell} from "../DssMultiIlkEmergencySpell.sol";

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
contract MultiLineWipeSpell is DssMultiIlkEmergencySpell {
    /// @notice The LineMom from chainlog.
    LineMomLike public immutable lineMom = LineMomLike(_log.getAddress("LINE_MOM"));
    /// @notice The AutoLine IAM.
    AutoLineLike public immutable autoLine = AutoLineLike(LineMomLike(_log.getAddress("LINE_MOM")).autoLine());
    /// @notice The Vat from chainlog.
    VatLike public immutable vat = VatLike(_log.getAddress("MCD_VAT"));

    /// @notice Emitted when the spell is scheduled.
    /// @param ilk The ilk for which the Clip breaker was set.
    event Wipe(bytes32 indexed ilk);

    /// @param _ilks The list of ilks for which the spell should be applicable
    /// @dev The list size is be at least 2 and less than or equal to 3.
    ///      The multi-ilk spell is meant to be used for ilks that are a variation of tha same collateral gem
    ///      (i.e.: ETH-A, ETH-B, ETH-C)
    ///      There has never been a case where MCD onboarded 4 or more ilks for the same collateral gem.
    ///      For cases where there is only one ilk for the same collateral gem, use the single-ilk version.
    constructor(bytes32[] memory _ilks) DssMultiIlkEmergencySpell(_ilks) {}

    /// @inheritdoc DssMultiIlkEmergencySpell
    function _descriptionPrefix() internal pure override returns (string memory) {
        return "Emergency Spell | Multi Line Wipe:";
    }

    /// @notice Wipes the line for the specified ilk..
    /// @param _ilk The ilk to be wiped.
    function _emergencyActions(bytes32 _ilk) internal override {
        lineMom.wipe(_ilk);
        emit Wipe(_ilk);
    }

    /// @notice Returns whether the spell is done or not for the specified ilk.
    function _done(bytes32 _ilk) internal view override returns (bool) {
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
