# NGINX Version Management

**Single Source of Truth** - Change one value to update both the Docker image tag AND the NGINX_VERSION environment variable.

## Quick Start

Edit **line 18** in `kustomization.yaml`:

```yaml
images:
  - name: public.ecr.aws/nginx/nginx
    newName: nginx
    newTag: 1.28-alpine  # ← CHANGE THIS ONE LINE
```

The `patches` section will automatically sync the `NGINX_VERSION` env var to match.

Then commit and push:

```bash
git add kustomization.yaml
git commit -m "Update NGINX to 1.28-alpine"
git push
```

---

## How It Works

When you change the `newTag` value in kustomization.yaml:

1. **Kustomize `images` field** updates the container image:
   ```yaml
   spec:
     containers:
       - name: nginx
         image: nginx:1.28-alpine  # ← Updated automatically
   ```

2. **JSON patch** updates the init container env var:
   ```yaml
   initContainers:
     - name: template-processor
       env:
         - name: NGINX_VERSION
           value: "1.28-alpine"  # ← Updated by patch
   ```

---

## Valid Versions

For **healthy deployment** (gets ✅ notification):
- `1.27-alpine`
- `1.28-alpine`
- `1.29-alpine`

For **degraded demo** (gets 🔴 notification):
- `99.99-alpine` (invalid - doesn't exist)
- `1.99-alpine` (invalid)

---

## Demo Flow

### 1. Start Healthy
Edit `kustomization.yaml` line 18: `newTag: 1.28-alpine`
```bash
git add kustomization.yaml
git commit -m "Set NGINX to valid version"
git push
# Wait for ArgoCD sync
# ✅ Get "nginx-alb is deployed and healthy" in Slack
```

### 2. Break It (Degraded Demo)
Edit `kustomization.yaml` line 18: `newTag: 99.99-alpine`
```bash
git add kustomization.yaml
git commit -m "Set NGINX to invalid version for demo"
git push
# Wait for ArgoCD sync
# 🔴 Get "nginx-alb is DEGRADED" alert in Slack
```

### 3. Fix It (Recovery Demo)
Edit `kustomization.yaml` line 18: `newTag: 1.28-alpine`
```bash
git add kustomization.yaml
git commit -m "Restore NGINX to valid version"
git push
# Wait for ArgoCD sync
# ✅ Get "nginx-alb is deployed and healthy" in Slack
```

---

## Files Modified

- `kustomization.yaml` - Contains both `images.newTag` and `patches` for env var sync

---

## Verification

After making changes, verify before committing:

```bash
# Build and check the output
kustomize build . | grep -A 5 "NGINX_VERSION"

# Should see:
#   - name: NGINX_VERSION
#     value: 1.28-alpine  # (matches your newTag)
```

---

## Author
Jian Ouyang (jian.ouyang@sapns2.com)
