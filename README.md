# How to use

Install all dependencies
    ```npm i```

## For local development
- Register your account in
    - [Alchemy](https://www.alchemy.com/) - for Etherium 
    - [GetBlock](https://getblock.io/) - for BSC

- Run hardhat mainnet fork
    - ``` npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/<your_alchemy_api_key> ``` - for Etherium
    - ``` npx hardhat node --fork https://bsc.getblock.io/?api_key=YOUR-API-KEY ``` - for BSC
    You can specify block number with ```--fork-block-number [number]```

- Compile contracts
    ``` npx  hardhat compile```
    See your compiled artifacts in ```artifacts``` folder
    
- Depoloy contracts
    ``` npx hardhat run --network development script/deploy_eth.js``` - for Ethereum
    ``` npx hardhat run --network development script/deploy_bsc.js``` - for BSC

## For non local development (Testnets)
- Create secrets.json file from secrets.example.json. **Pass real values to it**
    - projectId - your infura project id
    - mnemonic - your wallet mnemonic
- Deploy contracts
    ``` npx hardhat run --network [network_name] scripts/[deployment_script]```
    
    All availible networks are declared in ```hardhat.config.js ```
    Use ```testnet``` as [network_name] for deploying to BSC Testnet

# Flow

Manager creates new Fund using ```createFund()``` method on ```FundFactory``` contract. Manager need to have minimum 0.1 ETH on his balance

Created fund is ready to receiv investmens. 

Each fund has it`s own status:
   - Opened - fund is created and waiting for investmens
   - Active - users cannot make investmens anymore. Manager start trading process.
   - Complited - fund is over. All investmens are coming back to investors
   - Closed

When fund us opened, investors can put their money in it using ```makeDeposit()``` method.

Max cap of each fund is **100 ETH**.

Investors can withdraw their money before the fund became active

When fund manager decides to start the trading proccess, he call ```setFundStatusActive()``` method

Fund is started,and it`s active state can continue for 1/2/3/6 months.

Fund manager can trade only in active fund`s state.

For trading he can use those methods:
- ```swapERC20ToERC20()``` - swap ERC20 token to ERC20 token
- ```swapERC20ToETH()``` - swap ERC20 token to ether
- ```swapETHToERC20()``` - swap ether to ERC20 token

After 1/2/3/6 period of active state, fund can become completed. ```setFundStatusCompleted()```

Investors can receive their money back using ```withdraw()``` method

The rest of fund balance manager can withdraw to his account using ```withdrawToManager()```


# Contract addresses (Mainnet)
- ``` 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D ``` - UniswapV2Router
- ``` 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 ``` - PanckakeSwapRouter


**eFund token and oracle contract addresses you will get after their deployments**
