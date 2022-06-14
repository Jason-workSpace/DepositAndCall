// SPDX-License-Identifier: Apache-2.0
pragma solidity >= 0.8;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Helper is Ownable {
    using Address for address;

    address public gateway;
    address public target;
    bool public isRunning;
    bool public shouldTransferBack;
    mapping(bytes32 => address) helper;
    ExecuteDataContext internal context;

    bytes4 internal constant CALLID_DEFAULT_CONTEXT = bytes4(bytes32(type(uint256).max));
    address internal constant ADDRESS_DEFAULT_CONTEXT = address(type(uint160).max);

    event ExecuteSuccess(address indexed from, address indexed token, address target);
    event ShouldTransferBackChanged(uint256 block, bool shouldTransferBack);

    struct ExecuteDataContext {
        bytes4 callId; 
        address token;
        address to;
        address receiver; 
    }

    modifier checkRunning() {
        require(!isRunning);
        isRunning = true;
        _;
        isRunning = false;
    }

    function initialize(address _gateway, address _target) external  {
        require(gateway == address(0), "Already init");
        require(_target.isContract(), "_target should be a contract");
        // address zero is returned if no context is set, but the values used in storage
        // are non-zero to save users some gas (as storage refunds are usually maxed out)
        // EIP-1153 would help here
        context = ExecuteDataContext({
            callId: CALLID_DEFAULT_CONTEXT,
            token: ADDRESS_DEFAULT_CONTEXT,
            to: ADDRESS_DEFAULT_CONTEXT,
            receiver: ADDRESS_DEFAULT_CONTEXT
        });
        gateway = _gateway;
        target = _target;
    }

    function executeCallId() public view returns(bytes32) {
        bytes32 callId = context.callId;
        if(callId == CALLID_DEFAULT_CONTEXT) return bytes32(0);
        return callId;
    }

    function executeCallToken() public view returns(address) {
        address token = context.token;
        if(token == ADDRESS_DEFAULT_CONTEXT) return address(0);
        return token;
    }

    function executeTo() public view returns(address) {
        address to = context.to;
        if(to == ADDRESS_DEFAULT_CONTEXT) return address(0);
        return to;
    }

    function executeReceiver() public view returns(address) {
        address receiver = context.receiver;
        if(receiver == ADDRESS_DEFAULT_CONTEXT) return address(0);
        return receiver;
    }

    function changeTransferBackSetting(bool _shouldTransferBack) public onlyOwner  {
        require(_shouldTransferBack != shouldTransferBack, "Already set to the traget boolean value");
        shouldTransferBack = _shouldTransferBack;
        emit ShouldTransferBackChanged(block.number, _shouldTransferBack);
    }

    //@dev we shoud isContract
    function onTokenTransfer(
        address from, 
        uint256 amount, 
        bytes memory data
    ) public checkRunning returns (bool) {
        require(gateway == msg.sender, "Only gateway can call");
        ExecuteDataContext memory prevContext = context;
        bytes memory callHookdata;

        //@notice fill out context
        (context.callId, context.token, context.to, context.receiver, callHookdata) = abi.decode(data, (bytes4, address, address, address, bytes));

        uint256 preBalance;
        uint256 afterBalance;

        preBalance = IERC20(context.token).balanceOf(address(this));
        { 
            require(target == context.to, "Not right target address");
            // if the given token's address is correct and this function is called by
            // gateway, then there must be preBalance >= amount.
            require(preBalance >= amount, "Wrong token address encoded");
        }

        bytes memory returnData;
        bool executeSuccess;

        IERC20(context.token).approve(target, amount);

        //@notice execute main process
        (executeSuccess, returnData) = processCallDataAndSendTx(callHookdata);

        //@dev if an lp token send back or others token send back, we should handle it
        executeSuccess = afterTx(executeSuccess, returnData);
        require(executeSuccess, "afterTx execute failed");

        //@notice handle if still reamin token.
        {
            afterBalance = IERC20(context.token).balanceOf(address(this));
            require(preBalance > afterBalance, "Token not spent");

            if(shouldTransferBack) {
                uint256 remainBalance = preBalance - amount;
                if(afterBalance > remainBalance) {
                    IERC20(context.token).transfer(context.receiver, afterBalance - remainBalance);
                }
            } 

        }
        context = prevContext;
        emit ExecuteSuccess(from, context.token, target);
        return executeSuccess;
    }

    function processCallDataAndSendTx(bytes memory data) internal virtual returns(bool, bytes memory);
    function afterTx(bool success, bytes memory returnData) internal virtual returns(bool);
}