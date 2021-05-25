import React from 'react';
import './App.css';
import { Form } from "./components/Form/Form";
import "tailwindcss/tailwind.css"

export const App: React.FC = () => {
  return (
    <>
      <header><h1>Awesome EFund Project</h1></header>
      <div className="App">
        <Form />
      </div>
    </>
  );
}

