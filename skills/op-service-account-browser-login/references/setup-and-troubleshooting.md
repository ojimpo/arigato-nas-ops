# Setup and Troubleshooting

## One-time setup (server)

```bash
mkdir -p ~/.config/op
chmod 700 ~/.config/op
read -rsp "OP_SERVICE_ACCOUNT_TOKEN: " TOK; echo
printf 'OP_SERVICE_ACCOUNT_TOKEN=%s\n' "$TOK" > ~/.config/op/service-account.env
unset TOK
chmod 600 ~/.config/op/service-account.env
```

Load token for current shell:

```bash
set -a
source ~/.config/op/service-account.env
set +a
```

Verify:

```bash
op vault list
```

## Common issues

### `You are not currently signed in`

Service account token is not loaded in the current process.

Fix:

```bash
set -a; source ~/.config/op/service-account.env; set +a
```

### `vault not found`

Vault name mismatch (case, spaces, locale).

Fix:

```bash
op vault list
```

Copy exact name and quote it.

### Item exists but fields are empty

Item may use non-standard/custom field labels.

Fix:
- Inspect full item JSON:

```bash
op item get "<Item>" --vault "<Vault>" --format json
```

- Update script mapping if needed.

## Security notes

- Do not store service account token in the same vault the service account reads.
- Use least privilege (read-only, only required vaults).
- Do not post secrets in chat logs.
