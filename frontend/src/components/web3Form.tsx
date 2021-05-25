import React from "react";
import { provider } from "../services/ether";


export const Form: React.FC = () => {
  const signer = provider.getSigner();
  
  console.log(signer)
  
  return <div>I'm web3</div>
}