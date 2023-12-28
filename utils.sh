#!/bin/bash

if ! command -v forge &> /dev/null
then
    echo "Could not find foundry."
    echo "Please refer to the README.md for installation instructions."
    exit
fi

help_string="Available commands:
  help, -h, --help           - Show this help message
  test:local                 - Run local tests.
  coverage:lcov              - Generate an LCOV test coverage report.
  deploy:polygon-mumbai      - Deploy to Polygon Mumbai testnet

if [ $# -eq 0 ]
then
  echo "$help_string"
  exit
fi

case "$1" in
  "help") echo "$help_string" ;;
  "-h") echo "$help_string" ;;
  "--help") echo "$help_string" ;;
  "test:local") forge test ;;
  "coverage:integration") forge coverage --match-path "./src/*.sol" --report lcov --report summary ;;
  "deploy:polygon-mumbai") source .env && forge script SPDeploymentScript --ffi --chain-id 80001 --rpc-url $MUMBAI_RPC_URL --broadcast --verify --etherscan-api-key $POLYGONSCAN_API_KEY -vvv ;;
  *) echo "Invalid command: $1" ;;
esac