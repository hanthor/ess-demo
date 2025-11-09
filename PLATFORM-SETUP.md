# Platform-Specific Setup Instructions

Detailed setup instructions for each supported platform.

## 📱 Platform Support Matrix

| Platform | Architecture | Docker | Status | Notes |
|----------|-------------|---------|---------|-------|
| macOS | Intel (x86_64) | Desktop | ✅ Supported | Fully tested |
| macOS | Apple Silicon (arm64) | Desktop | ✅ Supported | Native ARM support |
| Linux | x86_64 (amd64) | Engine | ✅ Supported | Ubuntu, Fedora, Debian |
| Linux | ARM64 | Engine | ✅ Supported | Raspberry Pi 4+ |
| Windows | x86_64 (amd64) | Desktop | ✅ Supported | Windows 10/11 |

## 🍎 macOS Setup

### System Requirements
- **macOS:** 11.0 (Big Sur) or later
- **RAM:** 8GB minimum, 16GB recommended
- **Disk:** 20GB free space
- **CPU:** 4+ cores recommended

### Step-by-Step Setup

1. **Download Installers:**
   ```bash
   ./download-installers.sh
   ```
   
2. **Run Setup:**
   ```bash
   ./setup.sh
   ```

3. **Enter Domain:**
   When prompted, enter your domain (e.g., `ess.localhost`)

4. **Wait for Completion:**
   - Docker Desktop will start automatically
   - Kind cluster will be created
   - Certificates will be generated
   - ESS will be deployed (~5-10 minutes)

### macOS-Specific Notes

**Apple Silicon (M1/M2/M3):**
- Uses ARM64 architecture automatically
- Docker Desktop for Apple Silicon required
- Rosetta 2 not needed

**Intel Macs:**
- Uses x86_64 architecture
- Standard Docker Desktop for Mac

**Security Prompts:**
- Allow Docker Desktop in System Preferences → Security
- Enter admin password when installing mkcert CA

**Docker Desktop Settings (Recommended):**
- Resources → CPUs: 4
- Resources → Memory: 8GB
- Resources → Disk: 60GB

## 🐧 Linux Setup

### System Requirements
- **Distribution:** Ubuntu 20.04+, Fedora 35+, Debian 11+, or compatible
- **RAM:** 8GB minimum, 16GB recommended
- **Disk:** 20GB free space
- **CPU:** 4+ cores recommended
- **Kernel:** 5.0+

### Step-by-Step Setup

1. **Download Installers:**
   ```bash
   ./download-installers.sh
   ```

2. **Run Setup with sudo:**
   ```bash
   sudo ./setup.sh
   ```
   Or add your user to docker group first:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ./setup.sh
   ```

3. **Enter Domain:**
   When prompted, enter your domain (e.g., `ess.localhost`)

4. **Wait for Completion:**
   Setup will install Docker, create cluster, and deploy ESS

### Linux-Specific Notes

**Docker Installation:**
The script installs Docker from local binaries. For system package manager installation:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io

# Fedora
sudo dnf install docker

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```

**Firewall Configuration:**
```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Fedora (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

**SELinux (Fedora/RHEL):**
```bash
# Check status
sestatus

# If issues occur, add to permissive mode for testing
sudo setenforce 0
```

**ARM64 (Raspberry Pi):**
- Requires Raspberry Pi 4 or later (4GB+ RAM)
- Use 64-bit OS (Ubuntu 22.04 recommended)
- May need to increase swap space:
  ```bash
  sudo dphys-swapfile swapoff
  sudo nano /etc/dphys-swapfile  # Set CONF_SWAPSIZE=2048
  sudo dphys-swapfile setup
  sudo dphys-swapfile swapon
  ```

## 🪟 Windows Setup

### System Requirements
- **Windows:** 10 (build 19041+) or Windows 11
- **Edition:** Pro, Enterprise, or Education (for Hyper-V)
- **RAM:** 8GB minimum, 16GB recommended
- **Disk:** 20GB free space
- **CPU:** 4+ cores recommended, virtualization enabled

### Step-by-Step Setup

1. **Enable WSL2 and Hyper-V:**
   
   Open PowerShell as Administrator:
   ```powershell
   # Enable WSL2
   wsl --install
   
   # Enable Hyper-V (if not already enabled)
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   
   # Restart computer
   ```

2. **Download Installers:**
   
   Open PowerShell as Administrator:
   ```powershell
   .\download-installers.ps1
   ```

3. **Run Setup:**
   
   PowerShell as Administrator:
   ```powershell
   .\setup.ps1
   ```

4. **Enter Domain:**
   When prompted, enter your domain (e.g., `ess.localhost`)

5. **Wait for Completion:**
   - Docker Desktop will be installed
   - System may require restart
   - Re-run setup.ps1 after restart

### Windows-Specific Notes

**Docker Desktop Installation:**
- First run installs Docker Desktop
- Requires system restart
- Re-run `.\setup.ps1` after restart
- Docker must be running before continuing

**Execution Policy:**
If you get execution policy errors:
```powershell
# As Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run once:
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

**Windows Firewall:**
Docker Desktop usually configures this automatically, but if needed:
```powershell
# As Administrator
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
```

**WSL2 Backend:**
- Docker Desktop uses WSL2 backend (recommended)
- Ensure WSL2 is set as default:
  ```powershell
  wsl --set-default-version 2
  ```

**Resource Limits:**
Docker Desktop Settings:
- General → Use WSL2 based engine (checked)
- Resources → WSL Integration → Enable for your distro
- Resources → Advanced:
  - CPUs: 4
  - Memory: 8GB
  - Disk: 60GB

**Home Edition:**
Windows Home doesn't support Hyper-V. Use Docker Desktop with WSL2 backend instead (works on Home edition).

## 🌐 Network Configuration

### Using .localhost Domains (Recommended)

All platforms automatically resolve `*.localhost` to `127.0.0.1`:
- ✅ No DNS configuration needed
- ✅ Works offline
- ✅ No /etc/hosts editing

**Examples:**
- `ess.localhost`
- `chat.ess.localhost`
- `matrix.ess.localhost`

### Using Custom Domains

If using non-.localhost domains, add to hosts file:

**macOS/Linux:**
```bash
sudo nano /etc/hosts
```

Add:
```
127.0.0.1 ess.example.local
127.0.0.1 chat.ess.example.local
127.0.0.1 matrix.ess.example.local
127.0.0.1 auth.ess.example.local
127.0.0.1 admin.ess.example.local
127.0.0.1 mrtc.ess.example.local
```

**Windows:**
```powershell
# As Administrator
notepad C:\Windows\System32\drivers\etc\hosts
```

Add same entries as above.

## 🔧 Post-Installation Verification

### All Platforms

1. **Verify Docker:**
   ```bash
   docker --version
   docker ps
   ```

2. **Verify Cluster:**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

3. **Verify ESS:**
   ```bash
   ./verify.sh         # macOS/Linux
   .\verify.ps1        # Windows
   ```

4. **Access Element Web:**
   Open browser to: `https://chat.<your-domain>`

## 📊 Resource Usage by Platform

| Platform | Idle RAM | Active RAM | Disk Usage |
|----------|----------|------------|------------|
| macOS Intel | 4-5GB | 6-8GB | 8-12GB |
| macOS ARM | 3-4GB | 5-7GB | 8-12GB |
| Linux | 3-4GB | 5-7GB | 8-12GB |
| Windows | 5-6GB | 7-9GB | 10-14GB |

## 🚀 Performance Tips

### macOS
- Use native Apple Silicon builds (arm64)
- Increase Docker Desktop memory to 8GB+
- Use VirtioFS file sharing (Docker Desktop settings)

### Linux
- Use cgroups v2 for better resource management
- Consider using a lightweight window manager
- Enable CPU governor performance mode

### Windows
- Use WSL2 backend (not Hyper-V)
- Store files in WSL2 filesystem for better performance
- Disable Windows Defender real-time scanning for Docker directories

## 📱 Testing the Setup

After installation, verify all services:

```bash
# Check all pods are running
kubectl get pods -n ess

# Test connectivity
curl -k https://localhost
curl -k https://chat.<your-domain>

# Open in browser
# macOS:
open https://chat.<your-domain>

# Linux:
xdg-open https://chat.<your-domain>

# Windows:
start https://chat.<your-domain>
```

## 🔍 Platform-Specific Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed platform-specific issues and solutions.
