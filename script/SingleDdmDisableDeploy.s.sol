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
import {MCD, DssInstance} from "dss-test/MCD.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {SingleDdmDisableFactory} from "src/ddm-disable/SingleDdmDisableSpell.sol";

contract SingleDdmDisableDeployScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    string constant NAME = "single-ddm-disable-deploy";
    string config;

    SingleDdmDisableFactory fab;
    string[] ilkStrs;

    function run() external {
        config = ScriptTools.loadConfig();

        fab = SingleDdmDisableFactory(config.readAddress(".factory", "FOUNDRY_FACTORY"));
        ilkStrs = config.readStringArray(".ilks", "FOUNDRY_ILKS");

        vm.startBroadcast();

        for (uint256 i = 0; i < ilkStrs.length; i++) {
            bytes32 ilk = ilkStrs[i].stringToBytes32();
            address spell = fab.deploy(ilk);
            ScriptTools.exportContract(NAME, ilkStrs[i], spell);
        }
        vm.stopBroadcast();
    }
}
