1. Install truffle 
    ```npm install -g truffle```

2. Install all dependencies
    ```npm i```


## For local development
- Register your account in
    - [Alchemy](https://www.alchemy.com/) - Etherium 
    - [GetBlock](https://getblock.io/) - BSC

- Run hardhat mainnet fork
    - ``` npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/<your_alchemy_api_key> ``` - for Etherium
    - ``` npx hardhat node --fork https://bsc.getblock.io/?api_key=YOUR-API-KEY ``` - for BSC
    You can specify block number with ```--fork-block-number [number]```

- Depoloy contracts
    ``` truffle migrate --network development ```


## For non local development (Testnets)
- Create secrets.json file from secrets.example.json. **Pass real values to it**
    - projectId - your infura project id
    - mnemonic - your wallet mnemonic
- Deploy contracts
    ``` truffle migrate --network [network_name] ```

    All availible networks are declared in ``` truffle-config.json ```
    Use ```testnet``` as [network_name] for deploying to BSC Testnet


# Contract addresses (Mainnet)
- ``` 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D ``` - UniswapV2Router
- ``` 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 ``` - PanckakeSwapRouter

**eFund token and oracle contract addresses you will get after their deployments**
