// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
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

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {SingleLitePsmHaltSpellFactory, Flow} from "src/lite-psm-halt/SingleLitePsmHaltSpell.sol";

interface LitePsmLike {
    function ilk() external view returns (bytes32);
}

contract SingleLitePsmHaltDeployScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    string constant NAME = "single-lite-psm-halt-deploy";
    string config;

    SingleLitePsmHaltSpellFactory fab;
    address[] litePsms;

    function run() external {
        config = ScriptTools.loadConfig();

        fab = SingleLitePsmHaltSpellFactory(config.readAddress(".factory", "FOUNDRY_FACTORY"));
        litePsms = config.readAddressArray(".litePsms", "FOUNDRY_LITE_PSMS");

        vm.startBroadcast();

        for (uint256 i = 0; i < litePsms.length; i++) {
            address litePsm = litePsms[i];
            string memory ilkStr = _bytes32ToString(LitePsmLike(litePsm).ilk());
            ScriptTools.exportContract(NAME, string.concat(ilkStr, "_SELL"), fab.deploy(litePsm, Flow.SELL));
            ScriptTools.exportContract(NAME, string.concat(ilkStr, "_BUY"), fab.deploy(litePsm, Flow.BUY));
            ScriptTools.exportContract(NAME, string.concat(ilkStr, "_BOTH"), fab.deploy(litePsm, Flow.BOTH));
        }
        vm.stopBroadcast();
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
}
