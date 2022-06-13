// SPDX-License-Identifier: Apache-2.0
pragma solidity >= 0.8;
import "../Helper.sol";
import "../../Tester/nft.sol";

contract NFTMintHelper is Helper {
    
    
    /**
    * @param data this param doesn't need in this example.
    **/
    function processCallDataAndSendTx(bytes memory data) internal override returns(bool, bytes memory) {
        if(context.callId == bytes4(keccak256("buyItem()"))){
            NFTItem targetContract = NFTItem(target);
            uint256 tokenId = targetContract.buyItem();
            require(targetContract.ownerOf(tokenId) == address(this));
            return (true, abi.encode(tokenId));
        }
        else{
            revert("Not find the related call id");
        }
    }

    function afterTx(bool success, bytes memory data) internal override returns(bool) {
        require(success, "Not execute success");
        if(context.callId == bytes4(keccak256("buyItem()"))){
            NFTItem targetContract = NFTItem(target);
            uint256 tokenId = abi.decode(data,(uint256));
            targetContract.transferFrom(address(this), context.receiver, tokenId);
            return targetContract.ownerOf(tokenId) == context.receiver;
        }
        else{
            revert("Not find the related call id");
        }
    }
}