# ESS Community Demo - Quick Reference

## 🚀 Quick Commands

### Initial Setup
```bash
# 1. Download installers (one time, requires internet)
./download-installers.sh    # macOS/Linux
.\download-installers.ps1   # Windows

# 2. Run setup
./setup.sh                  # macOS/Linux
.\setup.ps1                 # Windows (as Administrator)
```

### Daily Operations
```bash
# Check status
./verify.sh                 # macOS/Linux
.\verify.ps1                # Windows

# View cluster
kubectl get pods -n ess
kubectl get svc -n ess
kubectl get ingress -n ess

# Interactive management
k9s -n ess

# View logs
kubectl logs -n ess <pod-name>
kubectl logs -n ess -l app.kubernetes.io/name=synapse

# Cleanup
./cleanup.sh                # macOS/Linux
.\cleanup.ps1               # Windows
```

## 📂 File Structure

```
ess-demo/
├── setup.sh / setup.ps1              # Main setup script
├── download-installers.sh / .ps1     # Download installers
├── cleanup.sh / cleanup.ps1          # Remove cluster
├── verify.sh / verify.ps1            # Check status
├── build-certs.sh                    # Certificate generation
│
├── installers/                       # Downloaded software
│   ├── macos/                        # macOS binaries
│   ├── linux/                        # Linux binaries
│   └── windows/                      # Windows binaries
│
├── demo-values/                      # Configuration files
│   ├── hostnames.yaml                # Auto-generated domains
│   ├── tls.yaml                      # TLS configuration
│   ├── auth.yaml                     # Auth settings
│   ├── mrtc.yaml                     # RTC configuration
│   └── pull-policy.yml               # Image pull policy
│
└── certs/                            # Generated certificates (auto-created)
```

## 🌐 Default URLs

Replace `<domain>` with your chosen domain (e.g., `ess.localhost`):

- **Element Web:** https://chat.`<domain>`
- **Admin Portal:** https://admin.`<domain>`
- **Matrix Server:** https://matrix.`<domain>`
- **Auth Service:** https://auth.`<domain>`
- **Matrix RTC:** https://mrtc.`<domain>`
- **Federation:** https://`<domain>`

## 🔧 Kubectl Cheat Sheet

```bash
# Switch context
kubectl config use-context kind-ess-demo

# View all resources
kubectl get all -n ess

# Describe a resource
kubectl describe pod <pod-name> -n ess

# Get pod logs (follow)
kubectl logs -f <pod-name> -n ess

# Execute command in pod
kubectl exec -it <pod-name> -n ess -- /bin/sh

# Port forward a service
kubectl port-forward -n ess svc/<service-name> 8080:8080

# Delete and recreate a pod
kubectl delete pod <pod-name> -n ess

# Scale a deployment
kubectl scale deployment <deployment-name> -n ess --replicas=2

# Apply a manifest
kubectl apply -f <file.yaml>

# Get events
kubectl get events -n ess --sort-by='.lastTimestamp'
```

## 🐛 Common Issues

### Docker Not Running
```bash
# macOS/Windows
# Start Docker Desktop from Applications

# Linux
sudo systemctl start docker
```

### Reset Everything
```bash
./cleanup.sh
./setup.sh
```

### View Resource Usage
```bash
kubectl top nodes
kubectl top pods -n ess
```

### Access Denied
```bash
# Windows: Run PowerShell as Administrator
# macOS/Linux: Use sudo where needed
```

### Certificate Issues
```bash
# Reinstall mkcert CA
mkcert -install

# Regenerate certificates
rm -rf certs/
./build-certs.sh demo-values/hostnames.yaml certs
```

## 📊 Monitoring

### Watch Pods
```bash
# Terminal
watch kubectl get pods -n ess

# k9s (interactive)
k9s -n ess
```

### Check Cluster Health
```bash
kubectl cluster-info
kubectl get nodes
kubectl get componentstatuses
```

## 🔄 Updates

### Update ESS
```bash
helm upgrade --install \
  --namespace ess \
  ess \
  oci://ghcr.io/element-hq/ess-helm/matrix-stack \
  -f demo-values/hostnames.yaml \
  -f demo-values/tls.yaml \
  -f demo-values/auth.yaml \
  -f demo-values/mrtc.yaml \
  -f demo-values/pull-policy.yml \
  --wait
```

## 📦 Portable Deployment

1. Download installers on machine with internet
2. Copy entire `ess-demo/` folder to USB/drive
3. Transfer to offline machine
4. Run `setup.sh` or `setup.ps1`

## 🎯 Next Steps

After setup:
1. ✓ Access Element Web at https://chat.`<domain>`
2. ✓ Create an account (requires registration token from admin)
3. ✓ Configure admin access at https://admin.`<domain>`
4. ✓ Test Matrix RTC features (audio/video calls)

## 📚 Documentation Links

- [ESS Helm Chart](https://github.com/element-hq/ess-helm)
- [Kind Docs](https://kind.sigs.k8s.io/)
- [kubectl Docs](https://kubernetes.io/docs/reference/kubectl/)
- [k9s Docs](https://k9scli.io/)
- [mkcert](https://github.com/FiloSottile/mkcert)
