# Keymaster – Development Guide

## Project Overview
Keymaster is a macOS CLI and HTTP daemon for secure Keychain access, protected by Touch ID / login password. Written in Swift with no external dependencies.

## Building

```shell
# CLI tool
swiftc keymaster.swift -o keymaster

# HTTP daemon
swiftc keymasterd.swift -o keymasterd

# inetd-style daemon
swiftc keymasterd-inetd.swift -o keymasterd-inetd
```

Use `-O` for release optimisation.

## Architecture

| Component | File | Purpose |
|---|---|---|
| CLI | `keymaster.swift` | Interactive `set`/`get`/`delete` via terminal |
| Daemon | `keymasterd.swift` | Persistent HTTP server on localhost |
| inetd Daemon | `keymasterd-inetd.swift` | On-demand, spawned by launchd per request |

All three share the same Keychain access pattern (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`) and authentication flow (`LAContext.evaluatePolicy`).

## Key Design Decisions

- **Single authentication per request**: The `get` command and `/keys/` endpoint authenticate once, then fetch all requested keys. This avoids multiple Touch ID prompts.
- **JSON by default**: The `get` command returns JSON (`{"key": ..., "value": ..., "error": ...}`). Use `--plain` for legacy raw-text output (single key only).
- **Comma-separated keys**: Both CLI (`keymaster get a,b,c`) and HTTP (`/keys/a,b,c`) use comma separation.
- **Partial success**: When fetching multiple keys, missing keys return `"error": "not found"` with `"value": null` instead of failing the whole request.
- **Backward compatibility**: `/key/<name>` endpoint still returns plain text. `--plain` flag preserves old CLI behaviour.

## Output Format

### CLI (`keymaster get`)
- Default: JSON to stdout, status to stderr
- `--plain`: raw secret value to stdout (single key only)

### HTTP daemon
- `GET /key/<name>` — plain text (backward compatible)
- `GET /keys/<name1>,<name2>` — JSON (`application/json`)

## Testing

No automated tests. Manual testing:

```shell
# Store test keys
./keymaster set test_key1 "value1"
./keymaster set test_key2 "value2"

# Single key JSON
./keymaster get test_key1

# Multiple keys
./keymaster get test_key1,test_key2

# Plain mode
./keymaster get test_key1 --plain

# Daemon
KEYMASTERD_PASSWORD=test keymasterd -u admin &
curl -u admin:test http://localhost:8787/keys/test_key1,test_key2
curl -u admin:test http://localhost:8787/key/test_key1
```
