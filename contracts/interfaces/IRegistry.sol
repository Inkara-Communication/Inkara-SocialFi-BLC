// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    function feeInfo(
        uint256 _salePrice
    ) external view returns (address, uint256);

    function platformContracts(address toCheck) external view returns (bool);

    function approvedCurrencies(
        address tokenContract
    ) external view returns (bool);

    function setSystemWallet(address newWallet) external;

    function setFeeVariables(uint256 newFee, uint256 newScale) external;

    function setContractStatus(address toChange, bool status) external;

    function setCurrencyStatus(address tokenContract, bool status) external;

    function approveAllCurrencies() external;
}
