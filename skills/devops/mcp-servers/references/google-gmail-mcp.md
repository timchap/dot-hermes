# Google Gmail MCP Server Setup

Google offers a remote HTTP MCP server for Gmail access. This is a **Developer Preview** feature
(part of the Google Workspace Developer Preview Program). Verified against
https://developers.google.com/workspace/gmail/api/guides/configure-mcp-server and
https://developers.google.com/workspace/gmail/api/reference/mcp (checked 2026-07).

## What It Does

- Read data: search email threads, retrieve threads, list labels
- Take action: create draft emails, create/apply/remove labels
- Security: inherits the same permissions and data governance controls as the user
- Does NOT support full email sending (only drafts) — no `send_message` tool exists

## Server Endpoint

Single global MCP endpoint (JSON-RPC 2.0 over HTTP, `Accept: application/json, text/event-stream`):

```
https://gmailmcp.googleapis.com/mcp/v1
```

(NOT `gmail.googleapis.com` — that's the REST API, a different host.)

## Step-by-Step Setup

### 1. Create a Google Cloud project
https://console.cloud.google.com/projectselector2/home/dashboard

### 2. Enable required APIs
```bash
gcloud services enable gmail.googleapis.com --project=PROJECT_ID
gcloud services enable gmailmcp.googleapis.com --project=PROJECT_ID
```
The second one is the **Gmail MCP API** — this is the actual API name in Cloud Console, not
"Google Cloud MCP Service".

### 3. Configure OAuth consent screen
Google Cloud console → Google Auth Platform → Branding (then Audience, Data Access).
- Audience: **Internal** if available, else **External** (add test users under Audience → Test users)
- Data Access → Add scopes — the exact scopes required by the Gmail MCP server are:
  - `https://www.googleapis.com/auth/gmail.readonly`
  - `https://www.googleapis.com/auth/gmail.compose`
  (NOT `gmail.modify` — the MCP server doesn't need or request that broader scope.)

### 4. Create OAuth 2.0 Client ID
Google Auth Platform → Clients → Create Client → **Web application** type (not Desktop, if
following Google's own Antigravity/Claude client instructions — redirect URI depends on the
MCP client you're pairing with, e.g. `https://antigravity.google/oauth-callback` for Antigravity).
For a custom proxy/integration, use whatever redirect URI your OAuth flow implementation expects.

### 5. Get a refresh token
Complete the OAuth 2.0 consent flow once (browser-based) to obtain a `refresh_token`. Exchange it
for short-lived access tokens as needed via `https://oauth2.googleapis.com/token`
(`grant_type=refresh_token`).

## Hermes Configuration

Add to `~/.hermes/config.yaml`:

```yaml
mcp_servers:
  gmail:
    url: "https://gmailmcp.googleapis.com/mcp/v1"
    headers:
      Authorization: "Bearer YOUR_ACCESS_TOKEN"
    timeout: 120
```

Note the access token is short-lived (~1hr) and Hermes' HTTP MCP transport does not itself refresh
OAuth tokens — see "OAuth isolation via proxy" in the parent SKILL.md if you want Hermes to never
hold the long-lived refresh token / client secret directly.

## Available Tools (verified toolset, checked 2026-07)

Tools appear as `mcp_gmail_*`. The **actual** tool names from Google's MCP reference are:
- `mcp_gmail_search_threads` — search email threads
- `mcp_gmail_get_thread` — retrieve a thread
- `mcp_gmail_list_labels` — list labels
- `mcp_gmail_create_label` — create a new label
- `mcp_gmail_create_draft` — create a draft email
- `mcp_gmail_list_drafts` — list drafts
- `mcp_gmail_label_message` / `mcp_gmail_label_thread` — apply a label to a message/thread
- `mcp_gmail_unlabel_message` — remove a label from a message

There is no `search_messages`, `get_message`, `add_message_labels`, or `remove_message_labels` —
those were wrong in an earlier version of this doc; don't invent tool names, always check
`tools/list` against the live server if unsure.

## Important Notes

- Developer Preview: API surface and auth flow may change — re-verify against the official docs
  above if something doesn't match.
- Token refreshes via Google's refresh token (no daily re-auth) but Hermes' MCP client does not
  manage that refresh cycle itself for HTTP servers — plan for how the access token gets renewed.
- No full send support — only drafts (compose in Gmail directly).
- If using 1Password for secrets, source the token dynamically rather than hardcoding in config.