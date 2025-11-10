# ESS Demo Air-gapped Package - TODO List

## ✅ Completed Tasks

### 1. Complete Ansible installers role (multi-platform)
**Status:** ✅ DONE

Enhanced `ansible/roles/installers/tasks/main.yml` with multi-platform support:
- Linux (amd64/arm64)
- macOS (arm64 only) 
- Windows (amd64)

Downloads:
- k3s v1.33.5+k3s1
- kubectl v1.31.3
- helm v3.19.0
- k9s v0.32.7
- mkcert v1.4.4
- zstd v1.5.6
- Rancher Desktop v1.16.0
- hauler v1.1.1

Generates `installers/index.json` manifest.

**Files:** 
- `ansible/roles/installers/tasks/main.yml`
- `ansible/roles/installers/vars/main.yml`

---

### 2. Create Ansible role for k3s setup (local)
**Status:** ✅ DONE

Created `ansible/roles/k3s-local` role:
- Installs k3s from downloaded binary (Linux amd64/arm64)
- Runs k3s install script with `--disable traefik`
- Waits for cluster ready
- Copies kubeconfig to project directory
- Sets KUBECONFIG environment variable

**Files:**
- `ansible/roles/k3s-local/tasks/main.yml`
- `ansible/roles/k3s-local/vars/main.yml`

---

### 3. Create Ansible role for ESS deployment
**Status:** ✅ DONE

Created `ansible/roles/ess-deploy` role:
- Extracts helm binary from installers
- Adds ingress-nginx Helm repository
- Installs ingress-nginx (v4.8.3)
- Generates TLS certificates (via build-certs.sh)
- Creates TLS secrets in matrix namespace
- Deploys matrix-stack chart with demo values:
  - hostnames.yaml
  - tls.yaml
  - auth.yaml
  - mrtc.yaml
  - pull-policy.yml
- Waits for all pods ready (20m timeout)

**Files:**
- `ansible/roles/ess-deploy/tasks/main.yml`
- `ansible/roles/ess-deploy/vars/main.yml`

---

### 4. Implement hauler cluster image capture
**Status:** ✅ DONE

Created `ansible/roles/hauler-capture` role:
- Extracts hauler binary from installers
- Runs `hauler store save -k --platform linux/amd64,linux/arm64`
- Captures ALL images from running k3s cluster (no manual manifest needed!)
- Includes ESS images + ingress-nginx + k3s runtime images
- Displays store info

**Files:**
- `ansible/roles/hauler-capture/tasks/main.yml`
- `ansible/roles/hauler-capture/vars/main.yml`

**Reference:** https://docs.hauler.dev/docs/guides-references/cluster-images

---

### 5. Add hauler Files manifest for installers
**Status:** ✅ DONE

Created `hauler-installers-manifest.yaml` in hauler-capture role:
- Contains Files section only (no Images - those come from cluster capture)
- K3s binaries (amd64/arm64)
- K3s airgap images (.tar.zst)
- K3s install script
- K3s SELinux RPMs
- kubectl (Linux/macOS/Windows)
- helm (Linux/macOS/Windows)
- k9s (Linux/macOS/Windows)
- mkcert (Linux/macOS/Windows)
- Rancher Desktop (macOS DMG, Windows MSI)

Syncs to hauler store after cluster image capture.

**Files:**
- `ansible/roles/hauler-capture/tasks/main.yml` (generates and syncs manifest)

---

## 🚧 In Progress / TODO

### 6. Create packaging tasks (per-OS tarballs)
**Status:** 🔲 NOT STARTED

Build Ansible role to create per-OS packages:
- `linux-airgap.tar.gz`
- `macos-airgap.tar.gz` 
- `windows-airgap.zip`

Each package should include:
- `installers/` directory (per-OS subset)
- `hauler-store/` (complete OCI store with all images)
- Setup scripts (k3s install, hauler load, helm deploy)
- Extraction scripts
- Package manifest (versions, checksums)

**Acceptance Criteria:**
- [ ] Create `ansible/roles/package` role
- [ ] Extract per-OS installer subset from installers/
- [ ] Copy hauler-store/ to package
- [ ] Generate setup scripts for each OS
- [ ] Create extraction/README for each package
- [ ] Generate package manifests with checksums
- [ ] Test package extraction on clean system

**Files to Create:**
- `ansible/roles/package/tasks/main.yml`
- `ansible/roles/package/vars/main.yml`
- `ansible/roles/package/templates/linux-setup.sh.j2`
- `ansible/roles/package/templates/macos-setup.sh.j2`
- `ansible/roles/package/templates/windows-setup.ps1.j2`

---

### 7. Add package extraction & test playbook
**Status:** 🔲 NOT STARTED

Create Ansible playbook to simulate end-user air-gapped deployment:

**Test Playbook:** `ansible/test-airgapped.yml`

Steps:
1. Extract package (tar/zip)
2. Install k3s from package
3. Load k3s airgap images
4. Extract and run hauler binary
5. Load hauler store images to containerd
6. Deploy ESS Helm chart using images from local containerd
7. Validate all pods running
8. Run smoke tests

**Acceptance Criteria:**
- [ ] Create `ansible/test-airgapped.yml` playbook
- [ ] Test on fresh Linux VM (no internet)
- [ ] Test on macOS (no internet) 
- [ ] Document any issues/gaps
- [ ] Verify all images load correctly
- [ ] Verify ESS deploys successfully
- [ ] Create validation/smoke tests

**Files to Create:**
- `ansible/test-airgapped.yml`
- `ansible/roles/airgap-test/tasks/main.yml`
- `ansible/roles/airgap-test/vars/main.yml`

---

### 8. Update Justfile & documentation
**Status:** 🔲 NOT STARTED

Replace bash recipe calls with Ansible playbook invocations.

**Justfile Updates:**
- [ ] Replace `setup` recipe: `ansible-playbook ansible/setup-playbook.yml`
- [ ] Add `build` recipe: Full build workflow
- [ ] Add `package` recipe: Create OS packages
- [ ] Add `test-airgap` recipe: Test air-gapped deployment
- [ ] Add `clean` recipe: Clean build artifacts
- [ ] Add `download-installers` recipe: Just installers role
- [ ] Add `capture-images` recipe: Just hauler capture

**Documentation Updates:**
- [ ] Update `README.md` with Ansible-only workflow
- [ ] Document prerequisites (Ansible, sudo access, disk space)
- [ ] Document build workflow
- [ ] Document air-gapped deployment workflow
- [ ] Add architecture diagram
- [ ] Add troubleshooting section
- [ ] Create `ANSIBLE-WORKFLOW.md` with detailed steps

**Files to Update:**
- `Justfile`
- `README.md`
- `ANSIBLE-WORKFLOW.md` (new)

---

## Workflow Overview

### Build Workflow (with internet):
```bash
# Full build
ansible-playbook ansible/setup-playbook.yml

# Step-by-step
ansible-playbook ansible/setup-playbook.yml --tags installers
ansible-playbook ansible/setup-playbook.yml --tags k3s
ansible-playbook ansible/setup-playbook.yml --tags ess,deploy
ansible-playbook ansible/setup-playbook.yml --tags hauler,capture
ansible-playbook ansible/setup-playbook.yml --tags package
```

### Air-gapped Deployment Workflow (no internet):
```bash
# Extract package
tar xzf linux-airgap.tar.gz
cd linux-airgap

# Deploy
ansible-playbook deploy-airgapped.yml
```

---

## Architecture

```
Build System (Internet)
├── ansible/roles/installers/     → Download all binaries
├── ansible/roles/k3s-local/       → Setup k3s cluster
├── ansible/roles/ess-deploy/      → Deploy ESS to k3s
├── ansible/roles/hauler-capture/  → Capture cluster images
└── ansible/roles/package/         → Create OS packages

Air-gapped System (No Internet)
└── ansible/test-airgapped.yml     → Extract & deploy from package
```

---

## Notes

- **k3s version:** v1.33.5+k3s1
- **helm version:** v3.19.0
- **hauler version:** v1.1.1
- **Platforms:** Linux (amd64/arm64), macOS (arm64), Windows (amd64)
- **Image capture method:** `hauler store save -k` (captures from live cluster)
- **No manual image manifest:** All images captured automatically from running cluster

---

**Last Updated:** 2025-11-10
