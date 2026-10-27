# Blockchain-Based Event Ticket Verification

## About the Project
This project uses blockchain technology and Solidity smart contracts to provide secure and transparent event ticket verification.

It helps prevent duplicate ticket usage, unauthorized transfers, and ticket fraud by recording ticket operations on the blockchain.

## Features
- **Event Creation:** Organizers can create events with details such as name, date, venue, and ticket price.
- **Ticket Generation:** Generate unique tickets for events.
- **Ticket Verification:** Verify ticket validity and ownership.
- **Duplicate-Use Prevention:** Mark tickets as used to prevent reuse.
- **Ticket Transfer:** Transfer tickets to another owner, if permitted by the smart contract.
- **Ticket Cancellation:** Invalidate tickets when cancellation is supported by the contract.
- **Transparency:** Store ticket-related records on the blockchain.

## Technologies Used
- Solidity
- Ethereum-compatible blockchain
- Remix IDE
- GitHub

## Smart Contract
The main smart contract is `EventTicketVerification.sol`.

## Deployment
1. Open [Remix IDE](https://remix.ethereum.org/).
2. Create or upload `EventTicketVerification.sol`.
3. Select the Solidity compiler version compatible with the contract's `pragma` statement.
4. Compile the smart contract.
5. Deploy it using the Remix JavaScript VM or a supported test network.
6. Interact with the deployed contract to create events and manage tickets.

## Project Purpose
The purpose of this project is to demonstrate how blockchain smart contracts can improve the security, transparency, and reliability of event ticket management.

## Disclaimer
This project is developed for educational purposes. Test the smart contract thoroughly before using it for real events or payments.
