// SPDX-License-Identifier: Apache-2.0
pragma solidity >= 0.8;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Helper.sol";
import "hardhat/console.sol";
contract TestGateway {
    address public erc20;
    function setToken(address _erc20) public {
        erc20 = _erc20;
    }
    function execute(address to, bytes calldata callHookData) public {
        IERC20(erc20).transfer(to, 10);
        Helper(to).onTokenTransfer(msg.sender,10,callHookData);
    }
}