# 🏥 Consent-Based Health Record Access Smart Contract

A blockchain-based solution for secure, patient-controlled health record access using Clarity smart contracts on the Stacks blockchain.

## 📋 Overview

This smart contract enables patients to maintain full control over their health records while allowing healthcare providers and researchers to request access through a transparent, consent-based system. All interactions are recorded on the blockchain, ensuring immutable audit trails and patient privacy.

## ✨ Features

- 👤 **Patient Registration**: Patients can register and manage their health records
- 🏥 **Healthcare Provider Verification**: Licensed providers can register and get verified
- 📄 **Health Record Management**: Secure storage of health record hashes
- 🤝 **Consent Requests**: Providers can request access to specific patient data
- ✅ **Grant/Deny Permissions**: Patients have full control over access decisions
- ⏰ **Time-Limited Access**: Consents expire automatically after specified duration
- 🔄 **Revoke Access**: Patients can revoke consent at any time
- 📊 **Access Tracking**: Monitor who accessed records and when

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new health-records-project
cd health-records-project
```

Copy the contract code into `contracts/Consent-Based-Health-Record-Access.clar`

## 📖 Usage Guide

### For Patients

#### 1. Register as a Patient
```clarity
(contract-call? .Consent-Based-Health-Record-Access register-patient "John Doe")
```

#### 2. Add Health Records
```clarity
(contract-call? .Consent-Based-Health-Record-Access add-health-record 0x1234... "blood-test")
```

#### 3. Grant Consent to Provider
```clarity
(contract-call? .Consent-Based-Health-Record-Access grant-consent 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### 4. Revoke Access
```clarity
(contract-call? .Consent-Based-Health-Record-Access revoke-consent 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### For Healthcare Providers

#### 1. Register as Provider
```clarity
(contract-call? .Consent-Based-Health-Record-Access register-healthcare-provider "City Hospital" "LIC123456")
```

#### 2. Request Patient Consent
```clarity
(contract-call? .Consent-Based-Health-Record-Access request-consent 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "Treatment planning" 
  u1000 
  (list "blood-test" "x-ray"))
```

#### 3. Access Health Records
```clarity
(contract-call? .Consent-Based-Health-Record-Access access-health-record 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🔍 Read-Only Functions

### Check Patient Information
```clarity
(contract-call? .Consent-Based-Health-Record-Access get-patient-info 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Verify Consent Status
```clarity
(contract-call? .Consent-Based-Health-Record-Access check-consent-validity 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE)
```

### Get Contract Statistics
```clarity
(contract-call? .Consent-Based-Health-Record-Access get-contract-stats)
```

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 🔒 Security Features

- ✅ Only verified healthcare providers can request access
- ✅ Patients maintain full control over their data
- ✅ Time-limited access prevents indefinite permissions
- ✅ Immutable audit trail of all access attempts
- ✅ Secure hash storage (actual records stored off-chain)

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Resource not found |
| u102 | Resource already exists |
| u103 | Consent expired |
| u104 | Invalid duration |
| u105 | Self-access not allowed |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For questions and support, please open an issue in the GitHub repository.

---

Built with ❤️ using Clarity and Stacks blockchain technology
```

**Git Commit Message:**
```
feat: implement consent-based health record access smart contract with patient-controlled permissions
```

**GitHub Pull Request Title:**
```
🏥 Add Consent-Based Health Record Access Smart Contract
```

**GitHub Pull Request Description:**
```
## Summary
Added a comprehensive smart contract for consent-based health record access that enables patients to maintain full control over their medical data while allowing secure, time-limited access for healthcare providers and researchers.

## What's Added
- ✅ Patient registration and health record management
- ✅ Healthcare provider verification system  
- ✅ Consent request and approval workflow
- ✅ Time-limited access controls with automatic expiration
- ✅ Access revocation capabilities
- ✅ Comprehensive audit trail and access tracking
- ✅ Read-only functions for data verification
- ✅ Complete documentation and usage examples

## Key Features
- 🔒 Patient-controlled access permissions
- ⏰ Automatic consent
