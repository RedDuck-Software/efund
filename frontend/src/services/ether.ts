import { ethers } from "ethers";
import FundFactory from "../build/contracts/FundFactory.json"

export const abi = JSON.stringify(FundFactory.abi)
export const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545/")
export const signer = provider.getSigner(0);
export const contract = new ethers.Contract("0x95401dc811bb5740090279Ba06cfA8fcF6113778", abi , signer);
