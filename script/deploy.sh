#!/bin/bash
source .env

contractName="$1"

if [ -z "$contractName" ]; then
  output=$(forge script script/Deploy.s.sol --chain base --rpc-url base --private-key $PRIVATE_KEY --verify -vvvv --broadcast --slow)
  
  contractName=$(echo "$output" | grep 'contractName:' | awk -F'"' '{print $2}')
else
  forge script script/Deploy.s.sol --chain base --rpc-url base --private-key $PRIVATE_KEY --sig "run(string memory contractName)" "$contractName" --verify -vvvv --broadcast --slow
fi 

OUT_DIR="./out/${contractName}.sol"
ARTIFACT="${OUT_DIR}/${contractName}.json"
TARGET_EVENT="ProductPriceSet"
EVENT_JSON="${OUT_DIR}/${TARGET_EVENT}.json"

# 1. Check if artifact exists
if [ ! -f "$ARTIFACT" ]; then
  echo "Artifact not found: $ARTIFACT"
  exit 1
fi

# 2. Extract the ABI element with name == "ProductPriceSet"
jq '.abi[] | select(.name == "'"$TARGET_EVENT"'")' "$ARTIFACT" > "$EVENT_JSON"

if [ ! -s "$EVENT_JSON" ]; then
  echo "Event $TARGET_EVENT not found in ABI."
  exit 1
fi

forge script script/WriteAddresses.s.sol --sig "run(string memory contractName)" "$contractName"

echo "Deployed contract: $contractName"
echo "Verify abi in deployments/addresses.json is correct!"