// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";

import {IKlasterERC20} from "../interface/IKlasterERC20.sol";
import {IKlasterAdapter} from "../interface/IKlasterAdapter.sol";
import {ICCIPLaneProvider} from "../interface/ICCIPLaneProvider.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    address public creator;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        creator = msg.sender;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

contract KlasterERC20 is ERC20, CCIPReceiver, IKlasterERC20, OwnerIsCreator {

    mapping (address => address) public adapters;
    ICCIPLaneProvider public laneProvider;

    constructor(
        string memory name,
        string memory symbol,
        ICCIPLaneProvider _laneProvider
    ) ERC20(name, symbol) CCIPReceiver(laneProvider.getChainConfig(block.chainid).router) {
        _addAdapters();
        laneProvider = _laneProvider;
    }

    /// @dev Modifier that checks if the chain with the given sourceChainSelector is the token with the same address.
    /// @param _sender The address of the sender.
    modifier validTokenAddress(address _sender) {
        require(_sender == address(this), "Only official token can be used to bridge.");
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }

    function registerAdapter(address targetContract, address adapter) external onlyOwner {
        adapters[targetContract] = adapter;
    }

    function rtc(
        uint256 chainId,
        uint256 bridgeAmount,
        address bridgeReceiver,
        uint256 allowanceAmount,
        address contractAddress,
        bytes memory callData,
        uint256 gasLimit,
        bool bridgeBack
    ) public payable returns (bytes32 messageId) {
        require(laneProvider.getChainConfig(block.chainid).router != address(0), "Source chain not supported.");
        require(laneProvider.getChainConfig(chainId).router != address(0), "Destination chain not supported.");
        
        _burn(msg.sender, (bridgeAmount + allowanceAmount));

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            address(this),
            abi.encode(msg.sender, bridgeAmount, bridgeReceiver, allowanceAmount, contractAddress, callData, bridgeBack),
            address(0),
            gasLimit
        );

        // Get the fee required to send the CCIP message
        uint256 fees = IRouterClient(
            laneProvider.getChainConfig(block.chainid).router
        ).getFee(
            laneProvider.getChainConfig(chainId).selector, evm2AnyMessage
        );
        require(address(this).balance >= fees, "Ether amount too low. Send more ether to execute ortc call.");

        // Send the CCIP message through the router and store the returned CCIP message ID
        messageId = IRouterClient(laneProvider.getChainConfig(block.chainid).router).ccipSend{value: fees}(
            laneProvider.getChainConfig(chainId).selector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit SendRTC(
            messageId,
            laneProvider.getChainConfig(chainId).selector,
            msg.sender,
            bridgeAmount,
            bridgeReceiver,
            allowanceAmount,
            contractAddress,
            bridgeBack,
            address(0),
            fees
        );
    }

    function getRtcFee(
        uint256 chainId,
        uint256 bridgeAmount,
        address bridgeReceiver,
        uint256 allowanceAmount,
        address contractAddress,
        bytes memory callData,
        uint256 gasLimit,
        bool bridgeBack
    ) external view returns (uint256) {
        ICCIPLaneProvider.ChainConfig memory sourceChainConfig = laneProvider.getChainConfig(block.chainid);
        ICCIPLaneProvider.ChainConfig memory destChainConfig = laneProvider.getChainConfig(chainId);
        require(sourceChainConfig.router != address(0), "Source chain not supported.");
        require(destChainConfig.router != address(0), "Destination chain not supported.");

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            address(this),
            abi.encode(msg.sender, bridgeAmount, bridgeReceiver, allowanceAmount, contractAddress, callData, bridgeBack),
            address(0),
            gasLimit
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(sourceChainConfig.router);

        // Get the fee required to send the CCIP message
        return router.getFee(destChainConfig.selector, evm2AnyMessage);
    }

    // @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for sending arbitrary bytes cross chain.
    /// @param _receiver The address of the receiver.
    /// @param _message The bytes data to be sent.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _message,
        address _feeTokenAddress,
        uint256 _gasLimit
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: _message, // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: _gasLimit, strict: false})
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
        return evm2AnyMessage;
    }

    /// handle received tokens
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        validTokenAddress(abi.decode(any2EvmMessage.sender, (address))) // Make sure the sender is the same token on different chain
    {

        (
            address sourceChainCaller,
            uint256 bridgeAmount,
            address bridgeReceiver,
            uint256 allowanceAmount,
            address contractAddress,
            bytes memory callData,
            bool bridgeBack
        ) = abi.decode(
            any2EvmMessage.data,
            (
                address,
                uint256,
                address,
                uint256,
                address,
                bytes,
                bool
            )
        );

        if (bridgeAmount > 0) { _mint(bridgeReceiver, bridgeAmount); }
        
        if (contractAddress != address(0) && allowanceAmount > 0) {
            // _mint(address(this), allowanceAmount);
            // _increaseAllowanceFor(address(this), contractAddress, allowanceAmount);
            if (adapters[contractAddress] != address(0)) {  // let adapter handle the RTC
                _mint(adapters[contractAddress], allowanceAmount);
                _increaseAllowanceFor(adapters[contractAddress], contractAddress, allowanceAmount);
                bool success = IKlasterAdapter(adapters[contractAddress]).execute( // Adapter will send ACK and optionally bridge back the resulting tokens
                    laneProvider.selectorToChainId(any2EvmMessage.sourceChainSelector),
                    sourceChainCaller,
                    callData,
                    bridgeBack
                );
            } else { // handle the RTC directly
                _mint(address(this), allowanceAmount);
                _increaseAllowanceFor(address(this), contractAddress, allowanceAmount);
                (bool success, bytes memory returnData) = contractAddress.call(callData);
                // TODO: Send ACK if success. Send NACK if fail. Handle the possibility of revert too.
            }
        } else {
            // TODO: Send Empty ACK (nothing to execute)
        }

        emit ReceiveRTC(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            sourceChainCaller,
            bridgeAmount,
            bridgeReceiver,
            allowanceAmount,
            contractAddress,
            bridgeBack
        );
    }

    function _addAdapters() internal {
        adapters[0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008] = 0x101Cd6a6E9B436eB3c14E8454bc17d15fF6D6239; // UniV2Adapter on Sepolia
        adapters[0x8d2915D89912Ba7bfBe2a5EA20BE6A1BBea7DB94] = 0xb5cFd3bDbD70DDD000835aF3cD5BAb73F20456Cf; // UniV2Adapter on Goerli Optimism
    }

    function _increaseAllowanceFor(address owner, address spender, uint256 addedValue) internal {
        _approve(owner, spender, allowance(address(this), spender) + addedValue);
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

}
