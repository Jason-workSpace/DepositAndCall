// SPDX-License-Identifier: Apache-2.0
pragma solidity >= 0.8;

abstract contract HelperUnit {
    function processCallData(bytes memory data) public virtual returns(bytes memory);
    function afterTxCallData(bytes memory returnData) public virtual returns(bool, address, bytes memory);
}