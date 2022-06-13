// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import "../HelperUnit.sol";
import "../HelperCenter.sol";
import "../../Tester/nft.sol";
import "hardhat/console.sol";

//@dev This is an example shows how to implement the logic
contract NFTMintUnit is HelperUnit {
    address public helperCenter; 

    function setHelperCenter(address _helperCenter) public {
        require(helperCenter == address(0), "Already init");
        helperCenter = _helperCenter;
    }

    function processCallData(bytes memory data) public view override returns(bytes memory){
        bytes4 callId = HelperCenter(helperCenter).executeCallId();
        if(callId == bytes4(keccak256("buyItem()"))) {
            bytes memory callHookData = abi.encodeWithSelector(callId);
            return callHookData;
        } else {
            revert("Not find the related call id");
        }
    }

    function afterTxCallData(bytes memory returnData) public view override returns(bool, address, bytes memory){
        bytes4 callId = HelperCenter(helperCenter).executeCallId();
        if(callId == bytes4(keccak256("buyItem()"))) {
            uint256 tokenId = abi.decode(returnData, (uint256));
            address receiver = HelperCenter(helperCenter).executeReceiver();
            address NFT = HelperCenter(helperCenter).executeTo();
            bytes4 transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
            bytes memory callHookData = abi.encodeWithSelector(transferFromSelector, helperCenter, receiver, tokenId);
            return (true, NFT , callHookData);        
        } else {
            revert("Not find the related call id");
        }
    }
}