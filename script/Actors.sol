// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

interface IActors {
    function ADMIN() external view returns (address);
    function PROPOSER_1() external view returns (address);
    function EXECUTOR_1() external returns (address);
}

contract LocalActors is IActors {
    address public constant ADMIN = address(1);
    address public constant PROPOSER_1 = address(1);
    address public constant EXECUTOR_1 = address(3);
}

contract HoleskyActors is IActors {
    address public constant ADMIN = 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913;
    address public constant PROPOSER_1 = 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913;
    address public constant EXECUTOR_1 = 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913;
}

contract MainnetActors is IActors {
    address public constant ADMIN = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;
    address public constant PROPOSER_1 = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;
    address public constant EXECUTOR_1 = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;
}
