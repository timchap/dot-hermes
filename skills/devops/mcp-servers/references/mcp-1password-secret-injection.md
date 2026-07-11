# 1Password Secret Injection Patterns for MCP Servers

When configuring MCP servers that require authentication, inject 1Password secrets
instead of hardcoding them. Use `{{VAR}}` in MCP `headers` values and define the
injection in `secrets.onepassword.env`.

## Secret Reference Formats

Both formats work:

### By item ID (shorter, more resilient to item renaming)
```
GMAIL_PROXY_SHARED_SECRET: op://hxt2lpmklletijcvpgc4qkpr3y/reveal
```

### By vault + item title (more human-readable)
```
GMAIL_PROXY_SHARED_SECRET: op://Hermes Readable/Hermes Gmail Proxy Shared Secret/password
```

Use `/reveal` for fields that need the actual secret value (passwords, tokens).
Use `/password` for password fields, or omit the suffix for the first string field.

## Example: HTTP MCP Server with Bearer Auth

```yaml
mcp_servers:
  gmail-proxy:
    url: "http://framework:8090/mcp/v1"
    headers:
      Authorization: "Bearer {{GMAIL_PROXY_SHARED_SECRET}}"
    timeout: 60

secrets:
  onepassword:
    enabled: true
    env:
      GMAIL_PROXY_SHARED_SECRET: op://Hermes Readable/Hermes Gmail Proxy Shared Secret/password
```

## Finding the Correct Reference

```bash
# List items in a vault
op item list --vault "Vault Name"

# Get item ID (for the short format)
op item list | grep "Item Title"

# Reveal a field to verify the format
op item get <item-id> --vault "Vault Name" --reveal
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Secret not resolving at runtime | Verify the `op://` reference format; check vault name matches exactly |
| `--reveal` doesn't work | Service account tokens may need `--vault` flag; check `op account list` |
| Header value is literally `{{VAR}}` | Ensure the env var name in `secrets.onepassword.env` matches the `{{VAR}}` exactly |
