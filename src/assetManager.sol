// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@sp1-contracts/contracts/src/ISP1Verifier.sol";
import {ItAsset} from "./interface/ItAsset.sol";
import "./interface/IassetManager.sol";


/**
 * @title AssetManager
 * @dev Manages user whitelists and orchestrates minting/burning of a specific ERC20 token.
 */
contract AssetManager is Ownable, IassetManager {
    // --- State Variables ---

    /// @dev ERC20 token contract being managed
    ItAsset public immutable token;

    /// @dev Struct for whitelisted user data
    struct WhitelistedUser {
        uint256 mintAllowance; // Total tokens the user is allowed to mint.
        uint256 mintedAmount; // Total tokens the user has already minted.
    }

    /// @dev Struct for zk-based user minting data
    struct ZkUser {
        uint256 mintedAmt; // Tokens already minted via zk-proof
        bytes32 latest_tx_hash; // Latest transaction hash tied to zk-proof
    }

    /// @notice Mapping of transaction hashes to their public values
    mapping(bytes32 => uint256) public tx_values;

    /// @notice Mapping of address → whitelist data
    mapping(address => WhitelistedUser) public whitelist;

    /// @notice Mapping of address → zk-user data
    mapping(address => ZkUser) public zkUsers;

    /// @notice Mapping of transaction hashes to prevent reuse
    mapping(bytes32 => bool) public usedTxHashes;

    /// @notice Verifier contract for zk-proofs
    address public verifier;

    /// @notice Program verification key for zk proof
    bytes32 public programVKey;

    /// @notice Native token decimals
    uint256 public nativeTokenDecimals;

    // --- Events ---

    event UserWhitelisted(address indexed user, uint256 allowance);
    event TokensMinted(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount);
    event ZkProofVerified(address indexed user, bytes32 txHash);
    event ProgramVKeyChanged(bytes32 newVKey);
    event VerifierChanged(address newVerifier);

    // --- Constructor ---

    /**
     * @dev Deploys AssetManager.
     * @param _tokenAddress Address of the ERC20 token contract.
     * @param initialOwner Address of the contract owner.
     * @param _verifier Address of the zk-proof verifier contract.
     * @param _programVKey Program verification key for zk proof.
     */
    constructor(
        address _tokenAddress,
        address initialOwner,
        address _verifier,
        bytes32 _programVKey,
        uint256 _nativeTokenDecimals
    ) Ownable(initialOwner) {
        require(
            _tokenAddress != address(0),
            "AssetManager: Invalid token address"
        );
        require(_verifier != address(0), "Invalid verifier");
        require(_nativeTokenDecimals <= 18, "Decimals > 18");
        token = ItAsset(_tokenAddress);
        verifier = _verifier;
        programVKey = _programVKey;
        nativeTokenDecimals = _nativeTokenDecimals;
    }

    // --- Whitelist Management ---

    /**
     * @dev Adds or updates a user's minting allowance. Only callable by the owner.
     * @param user The address of the user to whitelist.
     * @param allowance The total number of tokens the user is permitted to mint.
     */
    function setWhitelist(address user, uint256 allowance) external onlyOwner {
        require(
            user != address(0),
            "AssetManager: Cannot whitelist the zero address"
        );

        whitelist[user] = WhitelistedUser({
            mintAllowance: allowance,
            mintedAmount: 0
        });

        emit UserWhitelisted(user, allowance);
    }

    // --- Core Functions ---

    /**
     * @dev Allows a whitelisted user to mint tokens up to their allowance.
     * The AssetManager contract must have the MINTER_ROLE on the token contract.
     * @param amount The number of tokens to mint.
     */
    function mint(uint256 amount) external {
        WhitelistedUser storage user = whitelist[msg.sender];

        require(
            user.mintAllowance > 0,
            "AssetManager: You are not whitelisted"
        );
        require(amount > 0, "AssetManager: Amount must be greater than zero");
        require(
            user.mintedAmount + amount <= user.mintAllowance,
            "AssetManager: Mint amount exceeds allowance"
        );

        // Update state
        user.mintedAmount += amount;

        // Mint tokens
        token.mint(msg.sender, amount);

        emit TokensMinted(msg.sender, amount);
    }

    /**
     * @dev Allows minting based on zk-proof of a coin transaction.
     * @param _proofBytes zk-proof bytes to be verified.
     * @param _publicValues Public input values for the proof, encoded.
     */
    // add to contract state

    function mintWithZk(
        bytes calldata _proofBytes,
        bytes calldata _publicValues
    ) public {
        PublicValuesTx memory txResponse = verifyProof(
            _publicValues,
            _proofBytes
        );
        require(
            txResponse.total_amount > 0,
            "AssetManager: Invalid transaction"
        );

        // ensure the proof belongs to the caller
        require(
            txResponse.owner_address == msg.sender,
            "AssetManager: Proof owner mismatch"
        );

        bytes32 txHash = txResponse.tx_hash;
        require(!usedTxHashes[txHash], "AssetManager: tx hash already used");

        // Convert (8 decimals) to ERC20 (18 decimals)
        uint256 scale = 10 ** (18 - nativeTokenDecimals); 
        uint256 amount = uint256(txResponse.total_amount) * scale;
        require(amount > 0, "AssetManager: Amount must be greater than zero");

        ZkUser storage user = zkUsers[msg.sender];

        user.mintedAmt += amount;
        user.latest_tx_hash = txHash;

        // mark hash used before external call to mitigate reentrancy reuse
        usedTxHashes[txHash] = true;

        // Store the public values for this transaction
        tx_values[txHash] = amount;

        token.mint(msg.sender, amount);

        emit TokensMinted(msg.sender, amount);
    }

    /**
     * @dev Burns a specified amount of tokens from the caller's balance.
     * Caller must have approved AssetManager to spend tokens.
     * @param amount The number of tokens to burn.
     */
    function burn(uint256 amount) external {
        require(amount > 0, "AssetManager: Amount must be greater than zero");

        token.burnFrom(msg.sender, amount);

        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Checks if a user is whitelisted.
     * @param user The address of the user.
     * @return True if user is whitelisted.
     */
    function isWhitelisted(address user) external view returns (bool) {
        return whitelist[user].mintAllowance > 0;
    }

    /**
     * @dev Verifies a coin zk-proof using the verifier contract.
     * @param _publicValues Encoded public values of the transaction.
     * @param _proofBytes zk-proof to validate.
     * @return Struct containing decoded transaction data.
     */
    function verifyProof(
        bytes calldata _publicValues,
        bytes calldata _proofBytes
    ) internal returns (PublicValuesTx memory) {
        // 1. Verify the proof (reverts if invalid)
        ISP1Verifier(verifier).verifyProof(
            programVKey,
            _publicValues,
            _proofBytes
        );

        // 2. Decode the public values into your struct
        PublicValuesTx memory txResponse = abi.decode(
            _publicValues,
            (PublicValuesTx)
        );
        emit ZkProofVerified(msg.sender, keccak256(_proofBytes));
        return txResponse;
    }

    // --- Owner-only Setters ---

    /**
     * @dev Updates the zk program verification key.
     * @param _programVKey New program verification key.
     */
    function changeProgramVKey(bytes32 _programVKey) external onlyOwner {
        programVKey = _programVKey;
        emit ProgramVKeyChanged(_programVKey);
    }

    /**
     * @dev Sets the verifier contract address.
     * @param _verifier Address of the new verifier.
     */
    function setVerifier(address _verifier) external onlyOwner {
        require(
            _verifier != address(0),
            "AssetManager: Invalid verifier address"
        );
        verifier = _verifier;
        emit VerifierChanged(_verifier);
    }

    // --- Getter Functions ---

    /**
     * @dev Returns the total allowance a user has been granted.
     * @param user The address of the user.
     * @return The minting allowance.
     */
    function getAllowance(address user) external view returns (uint256) {
        return whitelist[user].mintAllowance;
    }

    /**
     * @dev Returns how many tokens a user has already minted.
     * @param user The address of the user.
     * @return The total minted amount.
     */
    function getMintedAmount(address user) external view returns (uint256) {
        return whitelist[user].mintedAmount;
    }

    /**
     * @dev Returns how many tokens a user has already minted via zk-proof.
     * @param user The address of the user.
     * @return The total minted amount.
     */
    function getZkMintedAmount(address user) external view returns (uint256) {
        return zkUsers[user].mintedAmt;
    }

    /**
     * @dev Returns how many tokens a user can still mint.
     * @param user The address of the user.
     * @return The remaining mintable amount.
     */
    function getMintableAmount(address user) external view returns (uint256) {
        WhitelistedUser storage whitelistedUser = whitelist[user];
        return whitelistedUser.mintAllowance - whitelistedUser.mintedAmount;
    }

    /**
     * @dev Returns verifier address that used to verify the proof.
     * @return returns the verifier address.
     */
    function getVerifier() external view returns (address) {
        return verifier;
    }

    /**
     * @dev Returns programVKey  that used to verify the proof.
     * @return returns the programVKey.
     */
    function getProgramVKey() external view returns (bytes32) {
        return programVKey;
    }

    function getAsset() external view returns (address){
        return address(token);
    }
}
