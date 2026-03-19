---
name: op-service-account-browser-login
description: Use 1Password Service Account credentials to perform browser logins non-interactively (OpenClaw browser/Relay workflows). Use when a user wants automatic sign-in to websites using credentials stored in a dedicated 1Password vault (for example OpenClaw), or when op signin session-based auth is unreliable across processes.
---

# 1Password Service Account Browser Login

Use this skill to log in to websites with credentials stored in 1Password, without manual password handling in chat.

## Workflow

1. Confirm prerequisites.
2. Resolve vault/item and fetch fields with `op`.
3. Open target login page and fill fields.
4. Submit only when user has requested execution.
5. Verify login result and report outcome.

## 1) Confirm prerequisites

Run:

```bash
set -a; source ~/.config/op/service-account.env; set +a
op vault list
```

If this fails, fix token setup first (see `references/setup-and-troubleshooting.md`).

## 2) Fetch credentials from 1Password

List candidate items:

```bash
set -a; source ~/.config/op/service-account.env; set +a
op item list --vault "<VaultName>" --categories Login
```

Fetch fields using the bundled script:

```bash
/home/kouki/clawd/skills/op-service-account-browser-login/scripts/op_get_login_fields.py \
  --vault "<VaultName>" --item "<ItemTitle>"
```

Script output is JSON with `username` and `password`.

## 3) Perform browser login

- Navigate to the login URL with browser automation.
- Snapshot to identify username/password/submit refs.
- Fill username and password into the correct inputs.
- Click submit only after user intent is clear (or explicitly requested).

## 4) Verify and report

After submit:

- Snapshot again and verify post-login signals (profile name, logout button, account page URL, etc.).
- Report success/failure succinctly.
- Never paste raw credentials into chat.

## Operational guardrails

- Use a dedicated automation vault (example: `OpenClaw`), not personal/private vault.
- Keep token outside the automation vault.
- Prefer least privilege: read-only vault access for service account.
- Avoid writing secrets to temporary files unless required; if required, delete immediately.

## Resources

- `scripts/op_get_login_fields.py`: deterministic extraction of username/password from a Login item.
- `references/setup-and-troubleshooting.md`: token setup, common errors, and quick fixes.
