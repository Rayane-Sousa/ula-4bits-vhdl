# ULA de 4 Bits em VHDL

Projeto desenvolvido para a disciplina de Sistemas Digitais da Universidade Federal do Rio de Janeiro (UFRJ).

## Descrição

Este projeto implementa uma Unidade Lógica e Aritmética (ULA) de 4 bits utilizando VHDL em uma FPGA Xilinx Spartan-3.

O sistema utiliza uma Máquina de Estados Finitos (FSM) para controlar a entrada dos dados através das chaves da FPGA e de um botão de confirmação. Também foi implementado um circuito de debounce para eliminar oscilações mecânicas do botão.

Os resultados e flags são exibidos através dos LEDs da FPGA.

---

## Operações Implementadas

| Opcode | Operação |
|---|---|
| 000 | ADD |
| 001 | SUB |
| 010 | INC |
| 011 | OR |
| 100 | AND |
| 101 | XOR |
| 110 | NEG |
| 111 | SHL |

---

## Flags Implementadas

- Z → Zero
- N → Negative
- C → Carry
- V → Overflow

---

## Arquitetura do Projeto

O sistema foi dividido nos seguintes blocos:

- Máquina de Estados Finitos (FSM)
- Registradores
- Unidade Lógica e Aritmética (ULA)
- Circuito de Debounce
- Interface de LEDs

---

## Tecnologias Utilizadas

- VHDL
- FPGA Xilinx Spartan-3
- Xilinx ISE
- ModelSim

---

## Simulações

O projeto foi validado através de simulações e testes em FPGA, verificando:

- Operações aritméticas
- Operações lógicas
- Flags de status
- Overflow
- Carry
- Funcionamento da FSM
- Circuito de debounce

---

## Autores

- Daniel Gudin
- João Gabriel
- Rayane Santos

---

## Disciplina

Sistemas Digitais — Universidade Federal do Rio de Janeiro (UFRJ)
