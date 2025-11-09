# Troubleshooting Guide

Common issues and solutions for the ESS Community portable demo.

## 🐳 Docker Issues

### Docker Daemon Not Running

**Symptoms:**
```
Cannot connect to the Docker daemon
Is the docker daemon running?
```

**Solutions:**

**macOS/Windows:**
```bash
# Start Docker Desktop from Applications menu
# Or via command line (macOS):
open -a Docker

# Wait for Docker to fully start (watch for whale icon)
```

**Linux:**
```bash
# Start Docker daemon
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Check Docker status
sudo systemctl status docker
```

### Docker Permission Denied (Linux)

**Symptoms:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Solutions:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in, or:
newgrp docker

# Verify
docker ps
```

### Docker Desktop Resource Limits

**Symptoms:**
- Pods stuck in Pending
- Out of memory errors
- Slow performance

**Solutions:**

**macOS/Windows Docker Desktop:**
1. Open Docker Desktop Settings
2. Go to Resources
3. Increase:
   - CPUs: 4+ cores
   - Memory: 8GB+ RAM
   - Disk: 20GB+ free space
4. Click "Apply & Restart"

## 🎯 Kind Cluster Issues

### Cluster Creation Fails

**Symptoms:**
```
ERROR: failed to create cluster
```

**Solutions:**
```bash
# Clean up any existing clusters
kind delete cluster --name ess-demo

# Remove Docker containers
docker ps -a | grep kind | awk '{print $1}' | xargs docker rm -f

# Retry setup
./setup.sh
```

### Port Already in Use

**Symptoms:**
```
ERROR: port 80 is already allocated
ERROR: port 443 is already allocated
```

**Solutions:**
```bash
# Find what's using the ports
# macOS/Linux:
sudo lsof -i :80
sudo lsof -i :443

# Windows:
netstat -ano | findstr :80
netstat -ano | findstr :443

# Stop conflicting services
# Apache:
sudo systemctl stop apache2

# Nginx:
sudo systemctl stop nginx

# IIS (Windows):
net stop w3svc

# Or change Kind port mappings in setup script
```

## 🔐 Certificate Issues

### Browser Certificate Warnings

**Symptoms:**
- "Your connection is not private"
- "NET::ERR_CERT_AUTHORITY_INVALID"

**Expected Behavior:**
This is normal for self-signed certificates!

**Solutions:**
1. Click "Advanced" or "Details"
2. Click "Proceed to [site]" or "Accept the Risk"
3. Certificate will be trusted on your local machine

**To fix permanently:**
```bash
# Reinstall mkcert CA
mkcert -install

# Verify CA installation
mkcert -CAROOT
```

### Certificate Generation Fails

**Symptoms:**
```
ERROR: mkcert not found
```

**Solutions:**
```bash
# Verify mkcert is installed
which mkcert

# Reinstall mkcert
# macOS:
brew install mkcert

# Linux:
# Use downloaded installer from installers/linux/

# Windows:
# Use downloaded installer from installers\windows\

# Initialize CA
mkcert -install
```

### Kubernetes Secret Not Created

**Symptoms:**
```
Error: secret "ess-well-known-certificate" not found
```

**Solutions:**
```bash
# Ensure namespace exists
kubectl create namespace ess

# Regenerate certificates
./build-certs.sh demo-values/hostnames.yaml certs

# Verify secrets
kubectl get secrets -n ess
```

## 🚀 Pod Issues

### Pods Stuck in Pending

**Symptoms:**
```
NAME                        READY   STATUS    RESTARTS
ess-synapse-0              0/1     Pending   0
```

**Solutions:**
```bash
# Check why pod is pending
kubectl describe pod <pod-name> -n ess

# Common causes and fixes:

# 1. Insufficient resources
# - Increase Docker Desktop resources
# - Check: kubectl describe nodes

# 2. Image pull issues
kubectl get pods -n ess
# If ImagePullBackOff, check internet connection

# 3. Persistent volume issues
kubectl get pvc -n ess
kubectl describe pvc <pvc-name> -n ess
```

### Pods in CrashLoopBackOff

**Symptoms:**
```
NAME                        READY   STATUS             RESTARTS
ess-synapse-0              0/1     CrashLoopBackOff   5
```

**Solutions:**
```bash
# Check logs
kubectl logs <pod-name> -n ess

# Check previous container logs
kubectl logs <pod-name> -n ess --previous

# Common issues:
# 1. Database not ready - wait a few minutes
# 2. Configuration error - check demo-values/
# 3. Resource limits - increase Docker resources

# Force pod recreation
kubectl delete pod <pod-name> -n ess
```

### ImagePullBackOff Errors

**Symptoms:**
```
Failed to pull image: context deadline exceeded
```

**Solutions:**
```bash
# Check internet connectivity
ping ghcr.io

# Check if image exists
docker pull ghcr.io/element-hq/ess-helm/matrix-stack

# Retry pod creation
kubectl delete pod <pod-name> -n ess

# Check pull secrets if using private registry
kubectl get secrets -n ess
```

## 🌐 Networking Issues

### Cannot Access URLs

**Symptoms:**
- `https://chat.<domain>` not loading
- Connection refused

**Solutions:**
```bash
# 1. Verify ingress is running
kubectl get pods -n ingress-nginx

# 2. Check ingress resources
kubectl get ingress -n ess

# 3. Verify ports are mapped
docker ps | grep kind

# 4. Test local connectivity
curl -k https://localhost

# 5. Check /etc/hosts (if not using .localhost)
# macOS/Linux:
cat /etc/hosts

# Windows:
type C:\Windows\System32\drivers\etc\hosts
```

### DNS Not Resolving

**Symptoms:**
- Domain not found
- DNS resolution failed

**Solutions:**
```bash
# Use .localhost domains (auto-resolve to 127.0.0.1)
# Example: ess.localhost, chat.ess.localhost

# Or manually add to /etc/hosts:
# macOS/Linux:
sudo nano /etc/hosts
# Add:
127.0.0.1 ess.yourdomain chat.ess.yourdomain matrix.ess.yourdomain

# Windows (as Administrator):
notepad C:\Windows\System32\drivers\etc\hosts
# Add same entries
```

## 📦 Helm Issues

### Helm Install Fails

**Symptoms:**
```
Error: failed to download "oci://ghcr.io/element-hq/ess-helm/matrix-stack"
```

**Solutions:**
```bash
# Check internet connection
ping ghcr.io

# Clear Helm cache
rm -rf ~/.cache/helm

# Retry with verbose output
helm install ess oci://ghcr.io/element-hq/ess-helm/matrix-stack \
  -n ess \
  -f demo-values/hostnames.yaml \
  --debug
```

### Helm Timeout

**Symptoms:**
```
Error: timed out waiting for the condition
```

**Solutions:**
```bash
# Check pod status
kubectl get pods -n ess

# Check events
kubectl get events -n ess --sort-by='.lastTimestamp'

# Increase timeout
helm upgrade --install ess oci://ghcr.io/element-hq/ess-helm/matrix-stack \
  -n ess \
  -f demo-values/hostnames.yaml \
  --timeout 15m
```

## 💾 Storage Issues

### Disk Space

**Symptoms:**
```
no space left on device
```

**Solutions:**
```bash
# Check Docker disk usage
docker system df

# Clean up unused Docker resources
docker system prune -a --volumes

# macOS/Windows: Increase Docker Desktop disk limit
# Settings → Resources → Disk image size

# Check host disk space
df -h
```

## 🔧 kubectl Issues

### Context Not Found

**Symptoms:**
```
error: context "kind-ess-demo" does not exist
```

**Solutions:**
```bash
# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context kind-ess-demo

# If cluster doesn't exist, recreate it
./cleanup.sh
./setup.sh
```

### Connection Refused

**Symptoms:**
```
Unable to connect to the server: dial tcp: lookup kind-control-plane
```

**Solutions:**
```bash
# Verify cluster is running
kind get clusters

# Verify Docker is running
docker ps

# Restart cluster
kind delete cluster --name ess-demo
./setup.sh
```

## 🖥️ Platform-Specific Issues

### macOS: Rosetta 2 (Apple Silicon)

**Symptoms:**
- Slow performance on M1/M2/M3 Macs
- Architecture warnings

**Solutions:**
- Ensure Docker Desktop for Apple Silicon is installed
- Downloads will automatically use arm64 architecture

### Windows: Execution Policy

**Symptoms:**
```
cannot be loaded because running scripts is disabled
```

**Solutions:**
```powershell
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass for single script
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

### Linux: SELinux Issues

**Symptoms:**
- Permission denied errors
- Pod security violations

**Solutions:**
```bash
# Check SELinux status
sestatus

# Temporarily set to permissive (for testing)
sudo setenforce 0

# Or add appropriate SELinux policies
```

## 🔄 Complete Reset

If all else fails, perform a complete reset:

```bash
# 1. Clean up existing installation
./cleanup.sh

# 2. Remove all Kind clusters
kind get clusters | xargs -I {} kind delete cluster --name {}

# 3. Clean Docker
docker system prune -a --volumes -f

# 4. Restart Docker
# macOS/Windows: Restart Docker Desktop
# Linux: sudo systemctl restart docker

# 5. Run setup again
./setup.sh
```

## 📞 Getting Help

If problems persist:

1. **Check logs:**
   ```bash
   kubectl logs -n ess <pod-name>
   kubectl describe pod -n ess <pod-name>
   kubectl get events -n ess
   ```

2. **Use k9s for interactive debugging:**
   ```bash
   k9s -n ess
   ```

3. **Verify system requirements:**
   - Docker running
   - 8GB+ RAM available
   - 20GB+ disk space
   - Admin/sudo privileges

4. **Check project issues:**
   - [ESS Helm Issues](https://github.com/element-hq/ess-helm/issues)
   - [Kind Issues](https://github.com/kubernetes-sigs/kind/issues)

5. **Enable debug mode:**
   ```bash
   # Add -x to scripts for verbose output
   bash -x ./setup.sh
   ```
