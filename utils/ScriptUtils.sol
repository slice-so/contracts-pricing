// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ISliceCore} from "./Slice/interfaces/ISliceCore.sol";
import {IProductsModule} from "./Slice/interfaces/IProductsModule.sol";
import {IFundsModule} from "./Slice/interfaces/IFundsModule.sol";
import {VmSafe} from "forge-std/Vm.sol";

/**
 * Helper contract to enforce correct chain selection in scripts
 */
abstract contract WithChainIdValidation is Script {
    ISliceCore public immutable SLICE_CORE;
    IProductsModule public immutable PRODUCTS_MODULE;
    IFundsModule public immutable FUNDS_MODULE;

    constructor(uint256 chainId, address sliceCore, address productsModule, address fundsModule) {
        require(block.chainid == chainId, "CHAIN_ID_MISMATCH");
        SLICE_CORE = ISliceCore(sliceCore);
        PRODUCTS_MODULE = IProductsModule(productsModule);
        FUNDS_MODULE = IFundsModule(fundsModule);
    }

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}

abstract contract EthereumScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            1,
            0x21da1b084175f95285B49b22C018889c45E1820d,
            0x689Bba0e25c259b205ECe8e6152Ee1eAcF307f5F,
            0x6bcA3Dfd6c2b146dcdd460174dE95Fd1e26960BC
        )
    {}
}

abstract contract OptimismScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            10,
            0xb9d5B99d5D0fA04dD7eb2b0CD7753317C2ea1a84,
            0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf,
            0x115978100953D0Aa6f2f8865d11Dc5888f728370
        )
    {}
}

abstract contract BaseScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            8453,
            0x5Cef0380cE0aD3DAEefef8bDb85dBDeD7965adf9,
            0xb9d5B99d5D0fA04dD7eb2b0CD7753317C2ea1a84,
            0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf
        )
    {}
}

abstract contract BaseGoerliScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            84531,
            0xAE38a794E839D045460839ABe288a8e5C28B0fc6,
            0x0FD0d9aa44a05Ee158DDf6F01d7dcF503388781d,
            0x5Cef0380cE0aD3DAEefef8bDb85dBDeD7965adf9
        )
    {}
}

abstract contract SetUpContractsList is Script {
    struct ContractMap {
        uint256 id;
        string path;
        string name;
    }

    struct ContractDeploymentData {
        string abi;
        address contractAddress;
        uint256 blockNumber;
        bytes32 transactionHash;
    }

    string constant ADDRESSES_PATH = "./deployments/addresses.json";
    string constant LAST_TX_PATH = "./broadcast/Deploy.s.sol/8453/run-latest.json";
    uint64 public constant CHAIN_ID = 8453;
    string public CONTRACT_PATH;

    ContractMap[] public contractNames;
    uint256 startId = 1;

    constructor(string memory path) {
        CONTRACT_PATH = path;
    }

    function setUp() public {
        _recordContractsOnPath(CONTRACT_PATH);
    }

    function writeAddressesJson(string memory contractName) public {
        string memory existingAddresses = vm.readFile(ADDRESSES_PATH);
        string memory newAddresses = "addresses";

        Receipt[] memory receipts = _readReceipts(LAST_TX_PATH);
        Tx1559[] memory transactions = _readTx1559s(LAST_TX_PATH);

        // Find the relevant transaction and receipt
        Tx1559 memory transaction;
        Receipt memory receipt;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (keccak256(bytes(transactions[i].contractName)) == keccak256(bytes(contractName))) {
                transaction = transactions[i];
                receipt = receipts[i];
                break;
            }
        }

        if (transaction.contractAddress == address(0)) {
            console.log("Transaction not found in broadcast artifacts");
            return;
        }

        // TODO: Retrieve abi from contract
        ContractMap memory contractMap;
        for (uint256 i = 0; i < contractNames.length; i++) {
            if (keccak256(bytes(contractNames[i].name)) == keccak256(bytes(contractName))) {
                contractMap = contractNames[i];
                break;
            }
        }
        string memory abiPath = string.concat("./out/", contractName, ".sol/ProductPriceSet.json");
        string memory abiValue = vm.readFile(abiPath);

        string memory key = string.concat(".", contractName, ".addresses");
        string memory addresses;
        if (vm.keyExistsJson(existingAddresses, key)) {
            // Append new data to existingAddresses
            bytes memory contractAddressesJson = vm.parseJson(existingAddresses, key);
            ContractDeploymentData[] memory existingContractAddresses =
                abi.decode(contractAddressesJson, (ContractDeploymentData[]));

            string[] memory json = new string[](existingContractAddresses.length + 1);
            vm.serializeAddress("0", "address", transaction.contractAddress);
            vm.serializeString("0", "abi", abiValue);
            vm.serializeUint("0", "blockNumber", receipt.blockNumber);
            json[0] = vm.serializeBytes32("0", "transactionHash", transaction.hash);

            for (uint256 i = 0; i < existingContractAddresses.length; i++) {
                ContractDeploymentData memory existingContractAddress = existingContractAddresses[i];
                string memory index = vm.toString(i + 1);

                vm.serializeAddress(index, "address", existingContractAddress.contractAddress);
                vm.serializeString(index, "abi", existingContractAddress.abi);
                vm.serializeUint(index, "blockNumber", existingContractAddress.blockNumber);
                json[i + 1] = vm.serializeBytes32(index, "transactionHash", existingContractAddress.transactionHash);
            }

            addresses = vm.serializeString("addresses", "addresses", json);
        } else {
            string[] memory json = new string[](1);
            vm.serializeAddress(contractName, "address", transaction.contractAddress);
            vm.serializeString(contractName, "abi", abiValue);
            vm.serializeUint(contractName, "blockNumber", receipt.blockNumber);
            json[0] = vm.serializeBytes32(contractName, "transactionHash", transaction.hash);
            addresses = vm.serializeString("addresses", "addresses", json);
        }
        vm.serializeJson(newAddresses, existingAddresses);
        newAddresses = vm.serializeString(newAddresses, contractName, addresses);

        vm.writeJson(newAddresses, ADDRESSES_PATH);
    }

    function _recordContractsOnPath(string memory path) internal {
        VmSafe.DirEntry[] memory files = vm.readDir(path);
        for (uint256 i = 0; i < files.length; i++) {
            VmSafe.DirEntry memory file = files[i];
            if (file.isDir) {
                _recordContractsOnPath(file.path);
            } else if (_endsWith(file.path, ".sol")) {
                string memory content = vm.readFile(file.path);
                if (_containsContractKeyword(content) && !_containsAbstractContractKeyword(content)) {
                    string memory contractName = _extractContractName(content);
                    contractNames.push(
                        ContractMap({id: startId++, path: string(abi.encodePacked(file.path)), name: contractName})
                    );
                }
            }
        }
    }

    function _extractContractName(string memory content) internal pure returns (string memory) {
        bytes memory contentBytes = bytes(content);
        bytes memory keyword = bytes("contract ");
        for (uint256 i = 0; i < contentBytes.length - keyword.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < keyword.length; j++) {
                if (contentBytes[i + j] != keyword[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                // Found "contract ", now extract the name
                uint256 start = i + keyword.length;
                uint256 end = start;
                while (
                    end < contentBytes.length
                        && (
                            (contentBytes[end] >= 0x30 && contentBytes[end] <= 0x39) // 0-9
                                || (contentBytes[end] >= 0x41 && contentBytes[end] <= 0x5A) // A-Z
                                || (contentBytes[end] >= 0x61 && contentBytes[end] <= 0x7A) // a-z
                                || (contentBytes[end] == 0x5F)
                        ) // _
                ) {
                    end++;
                }
                bytes memory nameBytes = new bytes(end - start);
                for (uint256 k = 0; k < end - start; k++) {
                    nameBytes[k] = contentBytes[start + k];
                }
                return string(nameBytes);
            }
        }
        return "";
    }

    function _containsContractKeyword(string memory content) internal pure returns (bool) {
        bytes memory contentBytes = bytes(content);
        bytes memory keyword = bytes("contract ");
        for (uint256 i = 0; i <= contentBytes.length - keyword.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < keyword.length; j++) {
                if (contentBytes[i + j] != keyword[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return true;
            }
        }
        return false;
    }

    function _containsAbstractContractKeyword(string memory content) internal pure returns (bool) {
        bytes memory contentBytes = bytes(content);
        bytes memory keyword = bytes("abstract contract ");
        for (uint256 i = 0; i <= contentBytes.length - keyword.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < keyword.length; j++) {
                if (contentBytes[i + j] != keyword[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return true;
            }
        }
        return false;
    }

    // Helper to check if a string ends with a suffix
    function _endsWith(string memory str, string memory suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(suffix);
        if (suffixBytes.length > strBytes.length) return false;
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            if (strBytes[strBytes.length - suffixBytes.length + i] != suffixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function _getFolderName(string memory path) internal view returns (string memory folderName) {
        bytes memory pathBytes = bytes(path);
        uint256 lastSlash = 0;
        uint256 prevSlash = 0;
        for (uint256 i = 0; i < pathBytes.length; i++) {
            if (pathBytes[i] == "/") {
                prevSlash = lastSlash;
                lastSlash = i;
            }
        }
        // If only one slash, return the first folder after src
        if (lastSlash == 0) return CONTRACT_PATH;
        // Find the folder name (between prevSlash and lastSlash)
        uint256 start = prevSlash == 0 ? 0 : prevSlash + 1;
        uint256 len = lastSlash - start;
        if (len == 0) return CONTRACT_PATH;
        bytes memory folderBytes = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            folderBytes[i] = pathBytes[start + i];
        }
        folderName = string(folderBytes);
    }

    // modified from `vm.readTx1559s` to read directly from broadcast artifact
    struct RawBroadcastTx1559 {
        string[] additionalContracts;
        bytes arguments;
        address contractAddress;
        string contractName;
        string functionSig;
        bytes32 hash;
        bool isFixedGasLimit;
        RawBroadcastTx1559Detail transactionDetail;
        string transactionType;
    }

    struct RawBroadcastTx1559Detail {
        uint256 chainId;
        address from;
        uint256 gas;
        bytes input;
        uint256 nonce;
        uint256 value;
    }

    function _readTx1559s(string memory path) internal view virtual returns (Tx1559[] memory) {
        string memory deployData = vm.readFile(path);
        bytes memory parsedDeployData = vm.parseJson(deployData, ".transactions");
        RawBroadcastTx1559[] memory rawTxs = abi.decode(parsedDeployData, (RawBroadcastTx1559[]));
        return _rawToConvertedEIPTx1559s(rawTxs);
    }

    function _rawToConvertedEIPTx1559s(RawBroadcastTx1559[] memory rawTxs)
        internal
        pure
        virtual
        returns (Tx1559[] memory)
    {
        Tx1559[] memory txs = new Tx1559[](rawTxs.length);
        for (uint256 i; i < rawTxs.length; i++) {
            txs[i] = _rawToConvertedEIPTx1559(rawTxs[i]);
        }
        return txs;
    }

    function _rawToConvertedEIPTx1559(RawBroadcastTx1559 memory rawTx) internal pure virtual returns (Tx1559 memory) {
        Tx1559 memory transaction;
        transaction.contractName = rawTx.contractName;
        transaction.contractAddress = rawTx.contractAddress;
        transaction.functionSig = rawTx.functionSig;
        transaction.hash = rawTx.hash;
        transaction.txDetail = _rawToConvertedEIP1559Detail(rawTx.transactionDetail);
        return transaction;
    }

    function _rawToConvertedEIP1559Detail(RawBroadcastTx1559Detail memory rawDetail)
        internal
        pure
        virtual
        returns (Tx1559Detail memory)
    {
        Tx1559Detail memory txDetail;
        txDetail.from = rawDetail.from;
        txDetail.nonce = rawDetail.nonce;
        txDetail.value = rawDetail.value;
        txDetail.gas = rawDetail.gas;
        return txDetail;
    }

    // modified from `vm.readReceipts` to read directly from broadcast artifact
    struct RawBroadcastReceipt {
        bytes32 blockHash;
        bytes blockNumber;
        address contractAddress;
        bytes cumulativeGasUsed;
        bytes effectiveGasPrice;
        address from;
        bytes gasUsed;
        bytes l1BaseFeeScalar;
        bytes l1BlobBaseFee;
        bytes l1BlobBaseFeeScalar;
        bytes l1Fee;
        bytes l1GasPrice;
        bytes l1GasUsed;
        RawReceiptLog[] logs;
        bytes logsBloom;
        bytes status;
        address to;
        bytes32 transactionHash;
        bytes transactionIndex;
        bytes typeValue;
    }

    function _readReceipts(string memory path) internal view returns (Receipt[] memory) {
        string memory receiptData = vm.readFile(path);
        bytes memory parsedReceiptData = vm.parseJson(receiptData, ".receipts");
        RawBroadcastReceipt[] memory rawReceipts = abi.decode(parsedReceiptData, (RawBroadcastReceipt[]));
        return _rawToConvertedReceipts(rawReceipts);
    }

    function _rawToConvertedReceipts(RawBroadcastReceipt[] memory rawReceipts)
        internal
        pure
        virtual
        returns (Receipt[] memory)
    {
        Receipt[] memory receipts = new Receipt[](rawReceipts.length);
        for (uint256 i; i < rawReceipts.length; i++) {
            receipts[i] = _rawToConvertedReceipt(rawReceipts[i]);
        }
        return receipts;
    }

    function _rawToConvertedReceipt(RawBroadcastReceipt memory rawReceipt)
        internal
        pure
        virtual
        returns (Receipt memory)
    {
        Receipt memory receipt;
        receipt.blockHash = rawReceipt.blockHash;
        receipt.to = rawReceipt.to;
        receipt.from = rawReceipt.from;
        receipt.contractAddress = rawReceipt.contractAddress;
        receipt.effectiveGasPrice = __bytesToUint(rawReceipt.effectiveGasPrice);
        receipt.cumulativeGasUsed = __bytesToUint(rawReceipt.cumulativeGasUsed);
        receipt.gasUsed = __bytesToUint(rawReceipt.gasUsed);
        receipt.status = __bytesToUint(rawReceipt.status);
        receipt.transactionIndex = __bytesToUint(rawReceipt.transactionIndex);
        receipt.blockNumber = __bytesToUint(rawReceipt.blockNumber);
        receipt.logs = rawToConvertedReceiptLogs(rawReceipt.logs);
        receipt.logsBloom = rawReceipt.logsBloom;
        receipt.transactionHash = rawReceipt.transactionHash;
        return receipt;
    }

    function __bytesToUint(bytes memory b) private pure returns (uint256) {
        require(b.length <= 32, "StdCheats _bytesToUint(bytes): Bytes length exceeds 32.");
        return abi.decode(abi.encodePacked(new bytes(32 - b.length), b), (uint256));
    }
}
