#!/bin/bash
source .env

contractName="$1"

if [ -z "$contractName" ]; then
  forge script script/Deploy.s.sol --chain base --rpc-url base --private-key $PRIVATE_KEY --verify -vvvv --broadcast --slow
else
  forge script script/Deploy.s.sol --chain base --rpc-url base --private-key $PRIVATE_KEY --sig "run(string memory contractName)" "$contractName" --verify -vvvv --broadcast --slow
fi 