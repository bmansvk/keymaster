# 🔑 Keymaster

<div align="center">
  <em>Secure macOS Keychain helper – guarded by <strong>Touch ID</strong> <em>and</em> your login password</em>
</div>


<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/swift-5.9-orange?logo=swift" />
  <img alt="macOS" src="https://img.shields.io/badge/macOS-12%20%2B-blue?logo=apple" />
  <img alt="License MIT" src="https://img.shields.io/badge/License-MIT-green" />
</p>


Keymaster is a tiny CLI that lets you store, retrieve, and delete small secrets in your macOS Keychain from scripts – protected by Touch ID or your login password. The first time you access a secret you can Always Allow the binary; every subsequent call prompts for biometrics and automatically falls back to a password sheet when Touch ID is unavailable.

---

## ✨ Features
- 🔐 Stores secrets in the system Keychain (kSecClassGenericPassword)
- 👆 Biometric protection via Touch ID
- 🔑 Automatic fallback to macOS login password
- ⚡️ Single self-contained binary, no dependencies
- 📝 Friendly CLI (set, get, delete) with built-in help
- 🛠 Written in Swift – easy to audit & build

---

## 📦 Installation

### Clone or download this repo
```shell
git clone https://github.com/bmansvk/keymaster.git
cd keymaster
```
### Compile
```swiftc keymaster.swift -o keymaster```

### Put the executable somewhere on your $PATH
```mv keymaster ~/.local/bin```  

Tip: Compile with -O for release optimisation.

---

## 🚀 Usage

```shell
keymaster set <key> <secret>              Store or update <secret> for <key>
keymaster get <key> [options]             Print secret to stdout
keymaster delete <key>                    Remove secret from Keychain

Options:
-h, --help                                Show detailed help and exit
-d, --description <text>                  Custom description for biometric prompt (get only)
```

### Examples

#### Save a GitHub token
```keymaster set github_token "ghp_abc123"```

#### Read it back
```GITHUB_TOKEN=$(keymaster get github_token)```

When running `get`, keymaster will show which key is being read:
```
Reading key "github_token" from Keychain...
```

#### Use a custom biometric prompt
```keymaster get vpn_password --description "VPN wants to authenticate"```

This will show "VPN wants to authenticate" in the Touch ID/password prompt instead of the default message.

#### Remove when no longer needed
```keymaster delete github_token```

Inside a Bash script:
```shell
#!/usr/bin/env bash
set -euo pipefail

API_KEY=$(keymaster get my_service_api_key)
curl -H "Authorization: Bearer $API_KEY" https://api.example.com/v1/...
```

---

## 🔒 How it works
1.	Keymaster calls SecItemAdd / SecItemCopyMatching / SecItemDelete from the Security framework.
2.	Before each operation it triggers LAContext.evaluatePolicy(.deviceOwnerAuthentication).
3.	macOS shows a single sheet:
- Touch ID or
- Use Password… → falls back to your login password.
4.	Only on success does the CLI proceed; otherwise it exits with a non-zero status.

Because secrets never leave the Keychain and the binary is code-signed by you, this approach is safer than environment variables or plain files.

---

## 🙏 Credits
Forked from johnthethird/keymaster – thanks for the original idea and groundwork.

---

📜 License

This project is licensed under the MIT License – see LICENSE for details.