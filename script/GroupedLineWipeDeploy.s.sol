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
import {GroupedLineWipeFactory} from "src/line-wipe/GroupedLineWipeSpell.sol";

contract GroupedLineWipeDeployScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    string constant NAME = "grouped-line-wipe-deploy";
    string config;

    GroupedLineWipeFactory fab;
    string[] ilkStrs;

    function run() external {
        config = ScriptTools.loadConfig();

        fab = GroupedLineWipeFactory(config.readAddress(".factory", "FOUNDRY_FACTORY"));
        ilkStrs = config.readStringArray(".ilks", "FOUNDRY_ILKS");

        bytes32[] memory ilks = new bytes32[](ilkStrs.length);
        for (uint256 i = 0; i < ilkStrs.length; i++) {
            ilks[i] = ilkStrs[i].stringToBytes32();
        }

        vm.startBroadcast();
        address spell = fab.deploy(ilks);
        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, description(ilkStrs), spell);
    }

    function description(string[] memory _ilkStrs) internal pure returns (string memory) {
        string memory buf = _ilkStrs[0];
        for (uint256 i = 1; i < _ilkStrs.length; i++) {
            buf = string.concat(buf, ", ", _ilkStrs[i]);
        }

        return buf;
    }
}
