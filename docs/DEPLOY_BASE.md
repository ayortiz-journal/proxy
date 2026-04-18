# Deployment Guide for Base Mainnet

This guide provides step-by-step instructions for deploying the Proxy contract to Base Mainnet using Foundry.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.
- - A wallet with Base ETH for gas.
  - - A BaseScan API Key.
   
    - ## Step 1: Navigate to the Contracts Directory
   
    - Open your terminal and navigate to the `contracts` folder:
   
    - ```bash
      cd contracts
      ```

      ## Step 2: Configure Environment Variables

      Create a `.env` file in the `contracts` directory based on the provided `.env.example`:

      ```bash
      cp .env.example .env
      ```

      Open the `.env` file and set the following variables:

      - `DEPLOYER_PRIVATE_KEY`: Your wallet's private key (ensure it has Base ETH).
      - - `TREASURY`: The address that will receive fees.
        - - `MAINNET`: Set to `true` for Base Mainnet deployment.
         
          - ```text
            DEPLOYER_PRIVATE_KEY=0xyour_private_key
            TREASURY=0xyour_treasury_address
            MAINNET=true
            ```

            ## Step 3: Deploy to Base Mainnet

            Run the following command to deploy the contract. Replace `<YOUR_BASESCAN_API_KEY>` with your actual BaseScan API key.

            ```bash
            forge script script/Deploy.s.sol:Deploy --rpc-url base --broadcast --verify --etherscan-api-key <YOUR_BASESCAN_API_KEY>
            ```

            ## Step 4: Manual Verification (Optional)

            If the automatic verification fails, you can manually verify the contract using this command:

            ```bash
            forge verify-contract <CONTRACT_ADDRESS> src/Proxy.sol:Proxy --chain 8453 --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 <TREASURY_ADDRESS>)
            ```

            Replace `<CONTRACT_ADDRESS>` with the address of the deployed contract and `<TREASURY_ADDRESS>` with your treasury address.
            
