# Nix Cache & Builder Secrets

This directory contains encrypted secrets for the Nix binary cache and distributed build system.

## Secrets Files

- **harmonia-signing-key.age** - Private key for signing binary cache packages
- **nix-builder-ssh-key.age** - SSH private key for remote builder authentication
- **nix-builder-ssh-pub.age** - SSH public key for remote builder authentication
- **cache-public-key.txt** - Reference file with the cache public key (NOT encrypted, for convenience)

## Scripts

### regenerate-nix-cache-secrets.sh

Generates new secrets from scratch. Use this if:
- You're setting up the cache for the first time
- You need to rotate keys
- You suspect keys are compromised

**Usage:**
```bash
cd secrets/
./regenerate-nix-cache-secrets.sh
```

**Important:** After running this script:
1. Copy the public key displayed and update `modules/nix-builder/client.nix`
2. Commit the new `.age` files
3. Deploy to all hosts

### verify-secrets.sh

Verifies that secrets are properly encrypted and can be decrypted.

**Usage:**
```bash
cd secrets/
./verify-secrets.sh
```

This will:
- Check all required secret files exist
- Attempt to decrypt each secret
- Verify the format is correct
- Display the public key for reference

## Manual Secret Operations

### View a secret:
```bash
agenix -d harmonia-signing-key.age
```

### Edit a secret:
```bash
agenix -e harmonia-signing-key.age
```

### Extract public key from signing key:
```bash
agenix -d harmonia-signing-key.age | cut -d: -f2
```

## After Regenerating Secrets

1. **Update client.nix with new public key:**
   ```bash
   # Get the public key
   PUBLIC_KEY=$(cat cache-public-key.txt)

   # Update client.nix
   cd ../modules/nix-builder/
   # Edit client.nix and change the default publicKey value
   ```

2. **Commit the secrets:**
   ```bash
   git add harmonia-signing-key.age nix-builder-ssh-key.age nix-builder-ssh-pub.age
   git commit -m "Rotate nix cache and builder secrets"
   ```

3. **Deploy to all hosts:**
   ```bash
   just switch nas-01     # Cache server
   just deploy nix-01     # Builders
   just deploy nix-02
   just deploy nix-03
   ```

## Troubleshooting

### "Cannot decrypt" error
- Make sure your SSH key is in `secrets.nix` under `users`
- Check that your SSH key is loaded: `ssh-add -l`

### "Invalid format" error
- The secret may be corrupted
- Re-run `regenerate-nix-cache-secrets.sh` to generate fresh secrets

### Forgot to save public key
```bash
# Extract it from the encrypted private key
agenix -d harmonia-signing-key.age
# The format is: nas-01-cache:BASE64KEY
```

## Security Notes

- **Private keys** (`.age` files) are encrypted with agenix and safe to commit
- **Public key** (`cache-public-key.txt`) can be safely shared
- **Never commit** unencrypted private keys
- Rotate keys periodically (every 6-12 months recommended)
