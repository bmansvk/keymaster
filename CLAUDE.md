# CLAUDE.md - AI Assistant Guide for Keymaster

This document provides comprehensive guidance for AI assistants working on the Keymaster codebase.

## Project Overview

**Keymaster** is a lightweight macOS CLI tool that provides secure secret storage using the macOS Keychain with biometric (Touch ID) and password authentication. The project is a security-focused utility that prioritizes simplicity and auditability.

### Key Facts
- **Language**: Swift 5.9+
- **Platform**: macOS 12+
- **Architecture**: Single-file CLI application
- **License**: MIT
- **Origin**: Fork of johnthethird/keymaster with significant enhancements

## Repository Structure

```
keymaster/
├── keymaster.swift    # Main (and only) source file
├── README.md          # User-facing documentation
├── LICENSE            # MIT License
└── CLAUDE.md          # This file - AI assistant guide
```

### Single-File Architecture
This is intentionally a single-file application for:
- Easy auditing of security-sensitive code
- Simple compilation and distribution
- Minimal dependencies (only Apple system frameworks)
- Clear code-signing and trust model

## Core Components

### 1. Keychain Operations (`keymaster.swift:14-56`)

Three fundamental operations interact with the macOS Keychain:

- **`setPassword(key:password:)`** - Stores or updates secrets using `kSecClassGenericPassword`
- **`getPassword(key:)`** - Retrieves secrets from the Keychain
- **`deletePassword(key:)`** - Removes secrets from the Keychain

All operations use `kSecAttrService` as the key identifier.

### 2. Authentication (`keymaster.swift:58-80`)

The `authenticate(reason:context:reply:)` function:
- Uses `LAContext` from LocalAuthentication framework
- Enforces `.deviceOwnerAuthentication` policy
- Sets `touchIDAuthenticationAllowableReuseDuration = 0` to force fresh biometrics every time
- Provides automatic fallback from Touch ID to password

### 3. CLI Interface (`keymaster.swift:82-202`)

Command structure:
```bash
keymaster set <key> <secret>              # Store secret
keymaster get <key> [--description <text>] # Retrieve secret
keymaster delete <key>                    # Remove secret
```

The `main()` function handles:
- Argument parsing
- Help display (`--help`, `-h`)
- Authentication triggering
- Asynchronous operation handling via `dispatchMain()`

## Development Workflow

### Building

```bash
# Debug build
swiftc keymaster.swift -o keymaster

# Release build (optimized)
swiftc -O keymaster.swift -o keymaster
```

### Testing

Since this is a CLI tool interacting with system frameworks:

1. **Manual Testing** is primary:
   ```bash
   ./keymaster set test_key "test_value"
   ./keymaster get test_key
   ./keymaster delete test_key
   ```

2. **Test authentication flows**:
   - Touch ID approval
   - Touch ID cancellation
   - Password fallback
   - Custom descriptions

3. **Test error cases**:
   - Non-existent keys
   - Empty secrets
   - Invalid arguments

### Local Development Setup

```bash
# Clone and enter directory
git clone https://github.com/bmansvk/keymaster.git
cd keymaster

# Build
swiftc keymaster.swift -o keymaster

# Test
./keymaster --help
```

## Code Organization

The code uses Swift's `// MARK: -` comments for organization:

1. **Keychain helpers** (`keymaster.swift:11-56`)
   - Core Security framework operations
   - Error handling via optional returns and status codes

2. **Authentication** (`keymaster.swift:58-80`)
   - LocalAuthentication integration
   - Biometric policy enforcement

3. **CLI** (`keymaster.swift:82-202`)
   - Argument parsing
   - User interaction
   - Main entry point

## Key APIs and Security Considerations

### Security Framework APIs Used
- `SecItemAdd` - Add items to keychain
- `SecItemCopyMatching` - Retrieve items from keychain
- `SecItemUpdate` - Update existing items
- `SecItemDelete` - Remove items from keychain

### LocalAuthentication APIs
- `LAContext.canEvaluatePolicy()` - Check authentication availability
- `LAContext.evaluatePolicy()` - Trigger authentication prompt
- `.deviceOwnerAuthentication` - Policy requiring Touch ID or password

### CRITICAL Security Principles

1. **Never bypass authentication**: All operations must call `authenticate()` first
2. **Fresh biometrics**: `touchIDAuthenticationAllowableReuseDuration = 0` must remain
3. **No plaintext storage**: Secrets must only exist in Keychain or in-memory during operations
4. **Fail securely**: Exit with `EXIT_FAILURE` on any security-relevant error
5. **User feedback**: Use `stderr` for messages, `stdout` only for secret output

## Common Modification Patterns

### Adding New Commands

When adding a new command:
1. Add to the switch statement in `main()` (keymaster.swift:150-198)
2. Update `printHelp()` with new usage (keymaster.swift:84-105)
3. Always require authentication before operations
4. Follow existing error handling patterns

### Modifying Authentication

When modifying authentication behavior:
- Test both Touch ID and password fallback paths
- Ensure `touchIDAuthenticationAllowableReuseDuration = 0` for security
- Maintain clear user feedback about what's being accessed

### Enhancing CLI Arguments

When adding options:
1. Parse in the argument parsing section (keymaster.swift:108-148)
2. Document in `printHelp()`
3. Update README.md examples
4. Maintain backwards compatibility with existing commands

## Swift Coding Conventions

### Style Used in This Project

- **Indentation**: 4 spaces
- **Line length**: Reasonable (no hard limit)
- **Naming**: camelCase for functions, parameters
- **Error handling**: Guard statements with early returns
- **Attributes**: `@discardableResult` for functions where return values are optional

### Patterns to Follow

```swift
// Good: Guard with early return
guard condition else {
    fputs("Error message\n", stderr)
    exit(EXIT_FAILURE)
}

// Good: Explicit type annotations in dictionaries
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    // ...
]

// Good: Asynchronous handling
authenticate(reason: reason) { success, error in
    guard success else {
        // Handle error
        exit(EXIT_FAILURE)
    }
    // Proceed with operation
    exit(EXIT_SUCCESS)
}
dispatchMain() // Keep alive for async operations
```

## Git Workflow

### Branch Strategy
- **Main branch**: Stable, tested code
- **Feature branches**: Use descriptive names (e.g., `add-list-command`, `fix-auth-timeout`)
- **Session branches**: AI sessions use `claude/` prefix with session ID

### Commit Message Style

Based on recent commits, use:
- Present tense, imperative mood
- Capitalize first letter
- Be descriptive but concise

Examples from history:
```
Add custom description support for biometric prompt on get command
General refactor with updated DOC
check biometrics when setting a key
added delete command
```

### Pre-commit Checks

Before committing:
1. Verify code compiles: `swiftc keymaster.swift -o keymaster`
2. Test basic operations manually
3. Ensure no debug code or temporary changes remain
4. Update README.md if CLI interface changed

## Testing Strategy

### Manual Test Checklist

For any changes, verify:

- [ ] **Compilation**: Code compiles without errors or warnings
- [ ] **Help display**: `keymaster --help` shows correct usage
- [ ] **Set operation**: Successfully stores a test secret
- [ ] **Get operation**: Successfully retrieves the test secret
- [ ] **Delete operation**: Successfully removes the test secret
- [ ] **Authentication**: Touch ID prompt appears with correct reason
- [ ] **Password fallback**: Works when Touch ID unavailable/declined
- [ ] **Error handling**: Appropriate errors for invalid input
- [ ] **Custom description**: `--description` flag works correctly (if applicable)
- [ ] **Stderr vs stdout**: Messages to stderr, secrets to stdout only

### Security Testing

When making security-related changes:
- Verify authentication is always required
- Confirm secrets never appear in error messages
- Test with different authentication states (Touch ID available/unavailable)
- Ensure failed authentication prevents operations

## Common Pitfalls to Avoid

1. **Don't output secrets to stderr**: Only stdout should receive secret values
2. **Don't cache authentication**: Each operation requires fresh authentication
3. **Don't add dependencies**: Keep the single-file, no-dependencies architecture
4. **Don't skip error checking**: Every Security framework call must check status
5. **Don't store secrets in variables longer than necessary**: Minimize in-memory lifetime
6. **Don't modify authentication requirements**: Keep the strict `.deviceOwnerAuthentication` policy

## Useful Context for AI Assistants

### When Making Changes

1. **Read the entire file first**: It's only ~200 lines
2. **Understand the security model**: This is a security tool, mistakes have consequences
3. **Preserve simplicity**: Resist over-engineering; single-file architecture is intentional
4. **Test authentication flows**: Touch ID and password paths both matter
5. **Update documentation**: README.md must reflect CLI changes

### Understanding User Needs

Users of Keymaster typically:
- Store API tokens, passwords, and credentials
- Call from shell scripts and automation
- Value security over convenience features
- Need reliable, predictable behavior
- Appreciate minimal dependencies

### Recent Development Themes

Based on commit history:
1. **Biometric enhancements**: Added auth to set/delete, custom descriptions
2. **Code quality**: Refactoring for clarity
3. **Feature additions**: New commands and options
4. **Documentation**: README improvements

## Related Resources

- **Apple Security Framework**: https://developer.apple.com/documentation/security
- **LocalAuthentication**: https://developer.apple.com/documentation/localauthentication
- **Swift CLI Best Practices**: https://swift.org/getting-started/#using-the-package-manager
- **Original Project**: https://github.com/johnthethird/keymaster

## Questions to Ask Before Changes

1. Does this change preserve the security model?
2. Will this work on macOS 12+?
3. Does this maintain the single-file architecture?
4. Have I tested both Touch ID and password paths?
5. Is the error handling consistent with existing patterns?
6. Does the README need updates?
7. Can this be simpler?

---

**Last Updated**: 2025-11-25
**Keymaster Version**: Based on commit 2cfb368 (Add custom description support for biometric prompt on get command)
