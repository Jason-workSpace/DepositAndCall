// SPDX-License-Identifier: Apache-2.0
pragma solidity >= 0.8;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Helper.sol";
import "hardhat/console.sol";
//@dev just used to act as gateway
contract TestGateway {
    address public erc20;
    function setToken(address _erc20) public {
        erc20 = _erc20;
    }
    function execute(address to, bytes calldata callHookData, uint256 amount) public {
        IERC20(erc20).transfer(to, amount);
        Helper(to).onTokenTransfer(msg.sender, amount, callHookData);
    }
}