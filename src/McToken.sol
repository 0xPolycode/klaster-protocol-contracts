// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";

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

interface ICCIPBridgeable {
    function bridge(uint256 chainId, uint256 amount) external payable returns (bytes32);
    function getBridgeFee(uint256 destChainId, address wallet, uint256 amount) external view returns (uint256);
}

contract McToken is ERC20, CCIPReceiver, ICCIPBridgeable, OwnerIsCreator {

    // Event emitted when a message is sent to another chain.
    event TokensBridged(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address wallet, // Wallet bridging the tokens.
        uint256 amount, // Amount of tokens bridged.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    // Event emitted when a message is received from another chain.
    event TokensReceived(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        address wallet, // Wallet bridging the tokens.
        uint256 amount  // Amount of tokens bridged. 
    );

    struct ChainConfig {
        address router;
        uint64 selector;
    }

    mapping (uint256 => ChainConfig) supportedChains; // (chainId -> chainDef) mapping

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) CCIPReceiver(_getRouterAddy(block.chainid)) {
        _addSupportedChains();
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

    function mint(address receiver, uint256 amount) external onlyOwner {
        _mint(receiver, amount);
    }

    function bridge(uint256 chainId, uint256 amount) external payable returns (bytes32 messageId) {
        ChainConfig memory sourceChainConfig = supportedChains[block.chainid];
        ChainConfig memory destChainConfig = supportedChains[chainId];
        require(sourceChainConfig.router != address(0), "Source chain not supported.");
        require(destChainConfig.router != address(0), "Destination chain not supported.");
        
        _burn(msg.sender, amount);

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            address(this),
            abi.encode(msg.sender, amount),
            address(0)
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(sourceChainConfig.router);

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(destChainConfig.selector, evm2AnyMessage);
        require(address(this).balance >= fees, "Ether amount too low. Send more ether to bridge...");

        // Send the CCIP message through the router and store the returned CCIP message ID
        messageId = router.ccipSend{value: fees}(
            destChainConfig.selector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit TokensBridged(
            messageId,
            destChainConfig.selector,
            address(this),
            msg.sender,
            amount,
            address(0),
            fees
        );

        // Return the CCIP message ID
        return messageId;
    }
    //
    //0.00360431377777777

    function getBridgeFee(uint256 destChainId, address wallet, uint256 amount) external view returns (uint256) {
        ChainConfig memory sourceChainConfig = supportedChains[block.chainid];
        ChainConfig memory destChainConfig = supportedChains[destChainId];
        require(sourceChainConfig.router != address(0), "Source chain not supported.");
        require(destChainConfig.router != address(0), "Destination chain not supported.");
    
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            address(this),
            abi.encode(wallet, amount),
            address(0)
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
        address _feeTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: _message, // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
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

        (address receiver, uint256 amount) = abi.decode(any2EvmMessage.data, (address, uint256));

        _mint(receiver, amount);

        emit TokensReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            receiver, amount
        );
    }

    // @notice Stores CCIP chain parameters.
    // Supported chains:
    //     - ETH Mainnet
    //     - ETH Sepolia Testnet
    //     - Optimism Mainnet
    //     - Optimism Goerli Testnet
    //     - Arbitrum Goerli Testnet
    //     - Avax Mainnet
    //     - Avax Fuji Testnet
    //     - Polygon Mainnet
    //     - Polygon Mumbai Testnet
    function _addSupportedChains() internal {
        supportedChains[1] = ChainConfig(_getRouterAddy(1), 5009297550715157269); // eth mainnet
        supportedChains[10] = ChainConfig(_getRouterAddy(10), 3734403246176062136); // optimism mainnet
        supportedChains[137] = ChainConfig(_getRouterAddy(137), 4051577828743386545); // polygon mainnet
        supportedChains[420] = ChainConfig(_getRouterAddy(420), 2664363617261496610); // optimism goerli testnet
        supportedChains[43113] = ChainConfig(_getRouterAddy(43113), 14767482510784806043); // avax fuji testnet
        supportedChains[43114] = ChainConfig(_getRouterAddy(43114), 6433500567565415381); // avax mainnet
        supportedChains[80001] = ChainConfig(_getRouterAddy(80001), 12532609583862916517); // polygon mumbai testnet
        supportedChains[421613] = ChainConfig(_getRouterAddy(421613), 6101244977088475029); // arbitrum goerli testnet
        supportedChains[11155111] = ChainConfig(_getRouterAddy(11155111), 16015286601757825753); // eth sepolia testnet
    }

    function _getRouterAddy(uint256 chainId) internal pure returns (address router) {
        if (chainId == 1)           { router = 0xE561d5E02207fb5eB32cca20a699E0d8919a1476; }
        if (chainId == 10)          { router = 0x261c05167db67B2b619f9d312e0753f3721ad6E8; }
        if (chainId == 137)         { router = 0x3C3D92629A02a8D95D5CB9650fe49C3544f69B43; }
        if (chainId == 420)         { router = 0xEB52E9Ae4A9Fb37172978642d4C141ef53876f26; }
        if (chainId == 43113)       { router = 0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8; }
        if (chainId == 43114)       { router = 0x27F39D0af3303703750D4001fCc1844c6491563c; }
        if (chainId == 80001)       { router = 0x70499c328e1E2a3c41108bd3730F6670a44595D1; }
        if (chainId == 421613)      { router = 0x88E492127709447A5ABEFdaB8788a15B4567589E; }
        if (chainId == 11155111)    { router = 0xD0daae2231E9CB96b94C8512223533293C3693Bf; }
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

}
