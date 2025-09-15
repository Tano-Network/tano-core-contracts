// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ItAsset {
    function mint(address to, uint256 amount) external;
    function garntMinterRole(address account) external;
    function burnFrom(address from, uint256 amount) external;
}