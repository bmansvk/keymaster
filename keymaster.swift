// Keymaster — secure Keychain helper guarded by Touch ID or your login password
//
// Build:  swiftc keymaster.swift -o keymaster
// Usage:  keymaster --help
// Forked: https://github.com/johnthethird/keymaster

import Foundation
import LocalAuthentication
import Security

// MARK: - Keychain helpers

@discardableResult
func setPassword(key: String, password: String) -> Bool {
    let passwordData = Data(password.utf8)
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: key,
        kSecValueData as String: passwordData,
    ]

    // Try to add first; if it already exists, update.
    let status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecDuplicateItem {
        let attrsToUpdate = [kSecValueData as String: passwordData]
        return SecItemUpdate(query as CFDictionary,
                             attrsToUpdate as CFDictionary) == errSecSuccess
    }
    return status == errSecSuccess
}

@discardableResult
func deletePassword(key: String) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: key,
    ]
    return SecItemDelete(query as CFDictionary) == errSecSuccess
}

func getPassword(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: key,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecReturnData as String: true,
    ]

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data,
          let pwd  = String(data: data, encoding: .utf8) else {
        return nil
    }
    return pwd
}

// MARK: - Authentication

/// Authenticate with Touch ID if available, otherwise the macOS login
/// password.  A single sheet is shown; pressing “Use Password…” switches
/// directly to the password prompt without needing a second call.
func authenticate(
    reason: String,
    context: LAContext = .init(),
    reply: @escaping (Bool, Error?) -> Void)
{
    // Force fresh biometrics every time.
    context.touchIDAuthenticationAllowableReuseDuration = 0

    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        reply(false, error)
        return
    }

    context.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: reason,
                           reply: reply)
}

// MARK: - JSON helpers

func jsonEscape(_ s: String) -> String {
    var out = ""
    for ch in s {
        switch ch {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default:
            if ch.asciiValue != nil && ch.asciiValue! < 0x20 {
                out += String(format: "\\u%04x", ch.asciiValue!)
            } else {
                out.append(ch)
            }
        }
    }
    return out
}

func jsonObject(_ pairs: [(String, Any)]) -> String {
    var entries: [String] = []
    for (key, value) in pairs {
        let k = "\"\(jsonEscape(key))\""
        let v: String
        if let s = value as? String {
            v = "\"\(jsonEscape(s))\""
        } else if let b = value as? Bool {
            v = b ? "true" : "false"
        } else if value is NSNull {
            v = "null"
        } else {
            v = "\"\(jsonEscape(String(describing: value)))\""
        }
        entries.append("\(k): \(v)")
    }
    return "{\(entries.joined(separator: ", "))}"
}

// MARK: - CLI

func printHelp() {
    print(
    """
    Keymaster — store & retrieve small secrets in your macOS Keychain,
    protected by Touch ID or your login password.

    USAGE:
      keymaster set <key> <secret>              Store or update <secret> for <key>
      keymaster get <key>[,<key2>,...] [options] Print secret(s) to stdout
      keymaster delete <key>                    Remove secret from Keychain

    OPTIONS:
      -h, --help                                Display this help message and exit
      -d, --description <text>                  Custom description for biometric prompt (get only)
      --plain                                   Output secret values only (no JSON)
                                                 Only valid with a single key.

    OUTPUT FORMAT:
      By default, `get` returns JSON:
        Single key:   {"key": "<name>", "value": "<secret>", "error": null}
        Multiple keys: [{"key": "<name>", "value": "<secret>", "error": null}, ...]
      With --plain, a single key's value is printed as raw text (legacy behaviour).

    EXAMPLES:
      keymaster set github_token "abc123"
      keymaster get github_token
      keymaster get github_token,gitlab_token,slack_token
      keymaster get github_token --plain
      keymaster get vpn_password --description "VPN wants to authenticate"
      keymaster delete github_token
    """)
}

func main() {
    var args = Array(CommandLine.arguments.dropFirst())

    // Early exit for --help.
    if let first = args.first, ["--help", "-h"].contains(first) {
        printHelp()
        exit(EXIT_SUCCESS)
    }

    guard args.count >= 2 else {
        printHelp()
        exit(EXIT_FAILURE)
    }

    let action = args.removeFirst()
    let keyArg = args.removeFirst()

    // Parse optional flags for "get" command
    var customDescription: String?
    var plainOutput = false
    var secret = ""

    if action == "get" {
        while !args.isEmpty {
            let arg = args.removeFirst()
            if arg == "--description" || arg == "-d" {
                if !args.isEmpty {
                    customDescription = args.removeFirst()
                }
            } else if arg == "--plain" {
                plainOutput = true
            }
        }
    } else if action == "set" {
        secret = args.first ?? ""
    }

    // For "get", split comma-separated keys
    let keys: [String]
    if action == "get" {
        keys = keyArg.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    } else {
        keys = [keyArg]
    }

    if keys.isEmpty {
        fputs("Error: no key names provided\n", stderr)
        exit(EXIT_FAILURE)
    }

    if plainOutput && keys.count > 1 {
        fputs("Error: --plain can only be used with a single key\n", stderr)
        exit(EXIT_FAILURE)
    }

    // Build authentication reason
    let authReason: String
    if let description = customDescription {
        authReason = description
    } else if keys.count == 1 {
        authReason = "\(action) the secret for \"\(keys[0])\""
    } else {
        authReason = "\(action) \(keys.count) secrets from the Keychain"
    }

    switch action {
    case "set", "get", "delete":
        // Show which key(s) are being accessed
        if action == "get" {
            let keyList = keys.map { "\"\($0)\"" }.joined(separator: ", ")
            fputs("Reading key(s) \(keyList) from Keychain...\n", stderr)
        }

        authenticate(reason: authReason) { success, error in
            guard success else {
                fputs("Authentication failed: \(error?.localizedDescription ?? "Unknown error")\n", stderr)
                exit(EXIT_FAILURE)
            }

            switch action {
            case "set":
                guard !secret.isEmpty else {
                    fputs("Error: <secret> missing for set action\n", stderr)
                    exit(EXIT_FAILURE)
                }
                guard setPassword(key: keys[0], password: secret) else {
                    fputs("Error writing to Keychain\n", stderr)
                    exit(EXIT_FAILURE)
                }
                print("✔ Key \"\(keys[0])\" stored successfully")

            case "get":
                if plainOutput {
                    // Legacy single-key plain text output
                    guard let pwd = getPassword(key: keys[0]) else {
                        fputs("No item found for \"\(keys[0])\"\n", stderr)
                        exit(EXIT_FAILURE)
                    }
                    print(pwd)
                } else {
                    // JSON output
                    var results: [String] = []
                    for k in keys {
                        let pwd = getPassword(key: k)
                        if let pwd = pwd {
                            results.append(jsonObject([("key", k), ("value", pwd), ("error", NSNull())]))
                        } else {
                            results.append(jsonObject([("key", k), ("value", NSNull()), ("error", "not found")]))
                        }
                    }
                    if keys.count == 1 {
                        print(results[0])
                    } else {
                        print("[\(results.joined(separator: ", "))]")
                    }
                }

            case "delete":
                guard deletePassword(key: keys[0]) else {
                    fputs("Error deleting item for \"\(keys[0])\"\n", stderr)
                    exit(EXIT_FAILURE)
                }
                print("✔ Key \"\(keys[0])\" deleted successfully")
            default: break // Unreached
            }
            exit(EXIT_SUCCESS)
        }

        // Keep the process alive while the asynchronous auth prompt is shown.
        dispatchMain()

    default:
        printHelp()
        exit(EXIT_FAILURE)
    }
}

main()