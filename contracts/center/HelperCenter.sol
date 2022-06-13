// SPDX-License-Identifier: Apache-2.0
pragma solidity >= 0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HelperCenter {
    using Address for address;

    address public gateway;
    bool shouldTransferBack;
    bool isRunning;
    bytes4 processCallData = bytes4(keccak256("processCallData(bytes)"));
    bytes4 afterTx = bytes4(keccak256("afterTxCallData(bytes)"));
    mapping(bytes32 => address) helper;
    ExecuteDataContext internal context;

    bytes4 internal constant CALLID_DEFAULT_CONTEXT = bytes4(bytes32(type(uint256).max));
    address internal constant ADDRESS_DEFAULT_CONTEXT = address(type(uint160).max);

    event ExecuteSuccess(bytes32 indexed helperId, address indexed from, uint256 block);
    event HelperLogicAdded(bytes32 indexed helperId, address indexed helper);

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

    function initialize(address _gateway) external  {
        require(gateway == address(0), "Already init");
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
    }

    function executeCallId() public view returns(bytes4) {
        bytes4 callId = context.callId;
        if(callId == CALLID_DEFAULT_CONTEXT) return bytes4(0);
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

    function addHelperLogic(bytes32 _helperId, address _helper) public {
        require(helper[_helperId] == address(0), "This helper already added");
        helper[_helperId] = _helper;
        emit HelperLogicAdded(_helperId, _helper);
    }

    function onTokenTransfer(address from, uint256 amount, bytes memory data) public checkRunning returns (bool success) {
        require(gateway == msg.sender, "Only gateway can call");
        require(from != address(0), "Not right address");
        ExecuteDataContext memory prevContext = context;
        bytes memory callPredata;
        bytes32 helperId;
        (helperId, context.callId, context.token, context.to, context.receiver, callPredata) = abi.decode(data,(bytes32, bytes4, address, address, address,bytes));
        
        require(context.to.isContract(), "to is not contract");
        
        IERC20(context.token).approve(context.to, amount);
        address helperCaller = helper[helperId]; 
        
        uint256 preBalance;
        uint256 afterBalance;
        bool executeSuccess;
        
        preBalance = IERC20(context.token).balanceOf(address(this));
        // if the given token's address is correct and this function is called by
        // gateway, then there must be preBalance >= amount.
        require(preBalance >= amount, "Wrong token address encoded");

        executeSuccess = execute(helperCaller, callPredata);

        require(executeSuccess, "execute failed");

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
        emit ExecuteSuccess(helperId, from, block.number);
        context = prevContext; 
        return true;
    }

    function execute(address helperCaller, bytes memory callPreData) internal returns(bool) {
        bool success;
        bool shouldAfterCall;
        bytes memory callHookData;
        bytes memory returnData;
        bytes memory afterCallerData;
        address afterCallerAddress;

        //@notice get calldata of the main process
        {    
            (success, callHookData) = helperCaller.staticcall(
                abi.encodeWithSelector(processCallData, callPreData)
            );
            require(success, "processCallData execute failed");
            
            callHookData = abi.decode(callHookData,(bytes));
            (success, returnData) = context.to.call(callHookData);
            require(success, "processCall execute failed");
        }

        //@notice get calldata of the process after main process
        {    
            (success, afterCallerData) = helperCaller.staticcall(
                abi.encodeWithSelector(afterTx, returnData)
            );
            require(success, "afterTx execute failed");
            (shouldAfterCall, afterCallerAddress, callHookData) = abi.decode(afterCallerData, (bool, address, bytes));

            //notice check if needed execute after call
            if(shouldAfterCall) {
                (success, returnData) = afterCallerAddress.call(callHookData);
                return success;
            }
        }
        return success;
    }
}