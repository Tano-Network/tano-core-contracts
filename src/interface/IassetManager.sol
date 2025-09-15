// SPDX-License-Identifier: MIT


pragma solidity ^0.8.20;

struct PublicValuesTx {
    uint64 total_amount;            // amount in satoshis
    bytes32 sender_address_hash;  // SHA256 of sender address
    address owner_address;        // Owner address
    bytes32 tx_hash;         // transaction hash
}
interface IassetManager {
    function setWhitelist(address user, uint256 allowance) external;
    function mint(uint256 amount) external;
        function mintWithZk(
        bytes calldata _proofBytes,
        bytes calldata _publicValues
    ) external;
    function burn(uint256 amount) external;
    function isWhitelisted(address user) external view returns (bool);
    function changeProgramVKey(bytes32 _programVKey) external;
    function getProgramVKey() external view returns (bytes32);
    function setVerifier(address _verifier) external;
    function getAllowance(address user) external view returns (uint256);
    function getMintedAmount(address user) external view returns (uint256);
    function getZkMintedAmount(address user) external view returns (uint256);
    function getMintableAmount(address user) external view returns (uint256);
    function getVerifier() external view returns (address);
    function getAsset() external view returns (address);
}