# Installers Directory

This directory stores locally downloaded installers for offline use.

## Structure

- `macos/` - macOS installers (arm64 and x86_64)
- `linux/` - Linux installers (amd64 and arm64)
- `windows/` - Windows installers (amd64)

## Downloading Installers

Run the appropriate download script from the root directory:

**macOS/Linux:**
```bash
./download-installers.sh
```

**Windows:**
```powershell
.\download-installers.ps1
```

This will download all required software:
- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Kind (Kubernetes in Docker)
- kubectl
- Helm
- k9s
- mkcert

## Offline Use

Once installers are downloaded, the setup scripts will use them automatically
without requiring internet access.
