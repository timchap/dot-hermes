# Google Gmail MCP Server Setup

Google offers a remote HTTP MCP server for Gmail access. This is a **Developer Preview** feature.

## What It Does

- Read data: search emails, retrieve threads, list labels
- Take action: create draft emails, label messages
- Security: inherits the same permissions and data governance controls as the user
- Does NOT support full email sending (only drafts)

## Step-by-Step Setup

### 1. Create a Google Cloud project
https://console.cloud.google.com/projectselector2/home/dashboard

### 2. Enable required APIs
In the API Library (https://console.cloud.google.com/apis/library), enable:
- **Gmail API**
- **Google Cloud MCP Service**

### 3. Configure OAuth consent screen
Go to https://console.cloud.google.com/apis/credentials → OAuth consent screen
- User type: **External** (personal) or **Internal** (Workspace org)
- Add scopes: `https://www.googleapis.com/auth/gmail.modify`
- Add yourself as a test user if app is in "Testing" mode

### 4. Create OAuth 2.0 Client ID
Credentials → Create Credentials → OAuth 2.0 Client ID → Application type: **Desktop app**
Download the JSON file.

### 5. Authorize for MCP access
Follow the MCP-specific authorization flow on the Google docs page to get an access token. This uses Google's MCP auth endpoint, not the standard Gmail OAuth flow.

## Hermes Configuration

Add to `~/.hermes/config.yaml`:

```yaml
mcp_servers:
  gmail:
    url: "https://gmail.googleapis.com/mcp/v1"
    headers:
      Authorization: "Bearer YOUR_ACCESS_TOKEN"
    timeout: 120
```

## Available Tools

Tools appear as `mcp_gmail_*`:
- `mcp_gmail_search_messages` — search emails
- `mcp_gmail_get_thread` — retrieve a thread
- `mcp_gmail_get_message` — retrieve a message
- `mcp_gmail_list_labels` — list labels
- `mcp_gmail_create_draft` — create a draft email
- `mcp_gmail_add_message_labels` — add labels to messages
- `mcp_gmail_remove_message_labels` — remove labels from messages

## Important Notes

- Developer Preview: API surface and auth flow may change
- Token refreshes via Google's refresh token (no daily re-auth)
- No full send support — only drafts (compose in Gmail directly)
- If using 1Password for secrets, source the token dynamically rather than hardcoding in config