import React from "react";
import { contract, signer } from "../../services/ether";
import "./Form.scss"

export const Form: React.FC = () => {
  // provider.listAccounts().then((result: string[]) => console.log(result))
  // const signer = provider.getSigner(0);
  
  console.log({ contract })
  signer.getAddress().then(console.log)
  
  const createNewFund = () => {
    // contract.connect(signer.provider)
    // console.log(contract)
    // contract.createFund("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", 1, [], ["0.1"])
  }
  
  return <div>
    <button onClick={createNewFund} >Create New </button>
  </div>
}