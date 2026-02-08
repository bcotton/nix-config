# Cloudflare Tunnel with Zero Trust Access

This guide covers exposing services to the internet securely using Cloudflare Tunnel with Zero Trust Access (SSO/MFA protection).

## Architecture

```
Internet User
      |
      v
[Cloudflare Access] <-- SSO login (Google) + MFA
      |
      v
[Cloudflare Edge]
      |
      v (encrypted tunnel)
[cloudflared on NixOS host]
      |
      v
[Your Service (e.g., localhost:13000)]
```

## Prerequisites

- Cloudflare account (free tier works)
- Domain registered/managed with Cloudflare DNS
- NixOS host with this configuration

## NixOS Configuration

### Enable the module

```nix
services.clubcotton.cloudflare-tunnel = {
  enable = true;
  tokenFile = config.age.secrets.cloudflare-tunnel-token.path;
};
```

### Create the secret

After configuring, create the encrypted token file:

```bash
agenix -e secrets/cloudflare-tunnel-token.age
# Paste the tunnel token from Cloudflare dashboard
```

## Cloudflare Dashboard Setup

### Step 1: Create a Tunnel

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
2. Navigate to: **Networks** -> **Tunnels**
3. Click **Create a tunnel**
4. Select **Cloudflared** as the connector type
5. Name your tunnel (e.g., "nix-01")
6. **Copy the token** - this is what goes in your agenix secret

### Step 2: Configure Public Hostname (Routing)

In the tunnel configuration:

1. Go to the **Public Hostname** tab
2. Click **Add a public hostname**
3. Configure:
   - **Subdomain**: `obsidian` (or your service name)
   - **Domain**: `clubcotton.org` (your domain)
   - **Type**: HTTP
   - **URL**: `localhost:13000` (your service's local port)

Repeat for each service you want to expose.

### Step 3: Set Up Identity Provider (Google)

1. Go to: **Settings** -> **Authentication**
2. Under **Login methods**, click **Add new**
3. Select **Google**
4. Follow the prompts to configure Google OAuth:
   - You'll need to create OAuth credentials in Google Cloud Console
   - Cloudflare provides step-by-step instructions

### Step 4: Create Access Application

1. Go to: **Access** -> **Applications**
2. Click **Add an application**
3. Select **Self-hosted**
4. Configure:
   - **Application name**: "Obsidian" (descriptive name)
   - **Session Duration**: 24 hours (or your preference)
   - **Application domain**: `obsidian.clubcotton.org`

### Step 5: Create Access Policy

In the application configuration:

1. Add a policy:
   - **Policy name**: "Allowed Users"
   - **Action**: Allow
   - **Include**:
     - Emails: `your-email@gmail.com`
     - Or: Emails ending in `@yourdomain.com`

## Adding New Services

To expose a new service:

1. **Cloudflare Dashboard**: Add a new public hostname in your tunnel config
2. **Cloudflare Access**: Create a new application with appropriate policy
3. No NixOS changes needed - the tunnel token handles all routing

## Verification

After deployment:

```bash
# Check the service is running
systemctl status cloudflared-tunnel

# View logs
journalctl -u cloudflared-tunnel -f

# Test the tunnel
curl -I https://obsidian.clubcotton.org
# Should redirect to Cloudflare Access login
```

In Cloudflare dashboard:
- **Networks** -> **Tunnels** should show your tunnel as "Healthy"

## Troubleshooting

### Tunnel shows "Inactive" or "Degraded"

```bash
# Check service status
systemctl status cloudflared-tunnel

# Check logs for errors
journalctl -u cloudflared-tunnel --since "10 minutes ago"

# Common issues:
# - Invalid token (re-copy from dashboard)
# - Network connectivity issues
# - Secret file permissions
```

### "Access Denied" when visiting service

- Verify your email is in the Access policy
- Check the application domain matches exactly
- Clear browser cookies and try again

### Service unreachable after Access login

- Verify the service is running locally: `curl localhost:13000`
- Check the public hostname configuration in Cloudflare
- Ensure the service port matches

## Security Considerations

- **Defense in depth**: Keep application-level auth (like Obsidian's basic auth) as a second layer
- **Session duration**: Shorter sessions are more secure but less convenient
- **Policy specificity**: Use specific email addresses rather than broad patterns
- **Audit logs**: Available in Zero Trust dashboard for compliance/monitoring
- **Token rotation**: Periodically rotate the tunnel token for security

## Cost

Cloudflare Zero Trust is free for up to 50 users. The tunnel itself is free with no bandwidth limits.

## References

- [Cloudflare Tunnel docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflare Access docs](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- [NixOS Cloudflared Wiki](https://wiki.nixos.org/wiki/Cloudflared)
