import { ethers } from "ethers";

declare global {
  interface Window {
    ethereum:any;
  }
}

export const provider = new ethers.providers.Web3Provider(window.ethereum)