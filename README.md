# 🏠 Decentralized Land Registry

> **Solving land disputes through immutable blockchain records** 🔐

A robust smart contract built on Stacks blockchain that provides an immutable, transparent, and decentralized solution for property registration and ownership tracking. This system eliminates corruption in traditional land registries by storing all property records permanently on the Bitcoin blockchain.

## 🚀 Features

- **Property Registration** 📋 - Register new properties with detailed information
- **Ownership Transfer** 🔄 - Securely transfer property ownership between parties  
- **Property Verification** ✅ - Authorized registrars can verify property authenticity
- **Dispute Management** ⚖️ - File and resolve property disputes on-chain
- **Ownership History** 📊 - Complete audit trail of all property transfers
- **Access Control** 🛡️ - Role-based permissions for registrars and administrators
- **Property Valuation** 💰 - Track and update property values over time

## 🏗️ Contract Architecture

### Core Data Structures

- **Properties Map**: Stores comprehensive property details including owner, location, size, type, value, and verification status
- **Transfer History**: Maintains complete record of all ownership transfers
- **Authorized Registrars**: Manages permissions for property registration and verification
- **Dispute System**: Tracks property disputes and their resolutions

### Key Functions

#### Public Functions 🔓

- `register-property` - Register a new property (authorized registrars only)
- `transfer-property` - Transfer ownership to another party
- `verify-property` - Verify property authenticity (authorized registrars only)
- `file-dispute` - File a dispute against a property
- `resolve-dispute` - Resolve property disputes (admin only)
- `update-property-value` - Update property market value
- `add-registrar` / `remove-registrar` - Manage authorized registrars (admin only)

#### Read-Only Functions 👁️

- `get-property` - Retrieve property details
- `get-property-owner` - Get current property owner
- `get-transfer-history` - View transfer history for a property
- `get-properties-by-owner` - List all properties owned by an address
- `is-property-verified` - Check if property is verified
- `verify-ownership` - Verify if claimed owner is actual owner
- `get-dispute` - Get dispute details for a property

## 🛠️ Installation & Setup

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Node.js (for testing)

### Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd decentralized-land-registry

# Check contract syntax
clarinet check

# Run tests
npm install
npm test

# Deploy to testnet
clarinet deploy --testnet
```

## 📖 Usage Guide

### 1. Register as Authorized Registrar

Only the contract admin can add registrars:

```clarity
(contract-call? .decentralized-land-registry add-registrar 'SP1REGISTRAR...)
```

### 2. Register a Property

Authorized registrars can register new properties:

```clarity
(contract-call? .decentralized-land-registry register-property 
  "123 Main Street, City, State" 
  u1500  ; size in sq ft
  "Residential" 
  u250000) ; value in microSTX
```

### 3. Transfer Property Ownership

Property owners can transfer their properties:

```clarity
(contract-call? .decentralized-land-registry transfer-property 
  u1  ; property ID
  'SP2NEWOWNER...  ; new owner address
  u300000  ; transfer value
  "Sale")  ; transfer type
```

### 4. Verify Property

Registrars can verify properties for authenticity:

```clarity
(contract-call? .decentralized-land-registry verify-property u1)
```

### 5. File a Dispute

Anyone can file a dispute against a property:

```clarity
(contract-call? .decentralized-land-registry file-dispute 
  u1  ; property ID
  'SP1DEFENDANT...  ; defendant address
  "Fraudulent documentation provided")
```

### 6. Query Property Information

Get comprehensive property details:

```clarity
(contract-call? .decentralized-land-registry get-property u1)
```

Check ownership:

```clarity
(contract-call? .decentralized-land-registry verify-ownership u1 'SP1OWNER...)
```

## 🧪 Testing

The contract includes comprehensive test coverage:

```bash
# Run all tests
npm test

# Run specific test suite
npm test -- --grep "property registration"
```

## 🔐 Security Features

- **Authorization Controls**: Only authorized registrars can register/verify properties
- **Ownership Validation**: Strict checks prevent unauthorized transfers
- **Immutable Records**: All data stored permanently on blockchain
- **Dispute Resolution**: Built-in mechanism for handling conflicts
- **Input Validation**: Comprehensive checks on all user inputs

## 🎯 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u401 | ERR_UNAUTHORIZED | User lacks required permissions |
| u403 | ERR_INVALID_OWNER | Sender is not property owner |
| u404 | ERR_PROPERTY_NOT_FOUND | Property ID doesn't exist |
| u405 | ERR_REGISTRAR_NOT_FOUND | Registrar not found |
| u406 | ERR_ALREADY_REGISTERED | Property already exists |
| u409 | ERR_PROPERTY_EXISTS | Duplicate property registration |
| u400 | ERR_INVALID_TRANSFER | Invalid transfer parameters |

## 🌟 Benefits

- **🛡️ Corruption Prevention**: Immutable records prevent tampering
- **📍 Transparency**: All transactions publicly viewable
- **⚡ Efficiency**: Automated processes reduce bureaucracy  
- **🌍 Global Access**: Accessible from anywhere in the world
- **💰 Cost Effective**: Lower fees than traditional systems
- **🔒 Security**: Secured by Bitcoin's proof-of-work

## 🚧 Future Enhancements

- Integration with legal frameworks
- Multi-signature property transfers
- Automated property tax calculations
- Integration with real estate marketplaces
- Mobile application interface
- Document storage via IPFS

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For questions or support, please open an issue in the repository.

---

**Built with ❤️ on Stacks blockchain** 🔥
