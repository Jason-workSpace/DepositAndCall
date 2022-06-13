// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
contract NFTItem is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address public erc20;
    constructor() ERC721("NFTItem", "NTM") {}

    function buyItem()
        public
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        IERC20(erc20).transferFrom(msg.sender, address(this), 10);
        
        _mint(msg.sender, newItemId);
        _tokenIds.increment();
        return newItemId;
    }

    function setToken(address _erc20) public {
        require(erc20 == address(0), "Already set");
        erc20 = _erc20;
    }
}