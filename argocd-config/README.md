# ArgoCD Health Checks and Notifications Setup

This directory contains ArgoCD notification configurations to alert you when applications become degraded, including image pull failures.

## Author
Jian Ouyang (jian.ouyang@sapns2.com)

## Components

### 1. Enhanced Application Configuration
**File:** `../argocd-apps/nginx-alb-app-enhanced.yaml`

Features:
- Automated sync with self-healing
- Retry policy for failed syncs (5 retries with exponential backoff)
- Notification annotations for Slack alerts
- Health monitoring

### 2. Notification ConfigMap
**File:** `argocd-notifications-cm.yaml`

Defines:
- Notification triggers (degraded, sync-failed, deployed, etc.)
- Notification templates with detailed messages
- Slack message formatting

### 3. Notification Secret
**File:** `argocd-notifications-secret.yaml`

Contains:
- Slack webhook URL (needs to be configured)
- Other notification service credentials

### 4. Image Validation Hooks
**Files:**
- `../k8s-manifests/nginx-alb/base/image-validation-hook.yaml` (requires Docker socket)
- `../k8s-manifests/nginx-alb/base/image-validation-hook-secure.yaml` (recommended, uses crane)

Pre-sync hooks that validate Docker images exist before deployment.

---

## Setup Instructions

### Step 1: Configure Slack Webhook

1. Create a Slack App and Incoming Webhook:
   - Go to https://api.slack.com/messaging/webhooks
   - Create a new app for your workspace
   - Add Incoming Webhook feature
   - Copy the webhook URL

2. Update the secret:
   ```bash
   # Edit the secret file
   vi argocd-notifications-secret.yaml

   # Replace YOUR_WORKSPACE_ID/YOUR_CHANNEL_ID/YOUR_SECRET_TOKEN
   # with your actual webhook URL
   ```

3. Apply the secret:
   ```bash
   kubectl apply -f argocd-notifications-secret.yaml
   ```

### Step 2: Apply Notification ConfigMap

```bash
# Apply the notification configuration
kubectl apply -f argocd-notifications-cm.yaml

# Update the ArgoCD URL context
kubectl patch configmap argocd-notifications-cm -n argocd --type merge -p '
{
  "data": {
    "context": "argocdUrl: https://your-argocd-url.com"
  }
}'
```

### Step 3: Enable Notifications Controller

Ensure ArgoCD notifications controller is running:

```bash
# Check if notifications controller is deployed
kubectl get deploy argocd-notifications-controller -n argocd

# If not, install it
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
```

### Step 4: Update Application with Notifications

Replace your current application with the enhanced version:

```bash
# Backup current application
kubectl get application nginx-alb -n argocd -o yaml > nginx-alb-app-backup.yaml

# Apply enhanced application
kubectl apply -f ../argocd-apps/nginx-alb-app-enhanced.yaml
```

### Step 5: Add Image Validation Hook (Optional but Recommended)

Update your kustomization.yaml to include the validation hook:

```bash
cd ../k8s-manifests/nginx-alb/base

# Edit kustomization.yaml and add:
# - image-validation-hook-secure.yaml
```

Then apply:
```bash
kubectl apply -k ../k8s-manifests/nginx-alb/overlays/dev
```

---

## Testing the Setup

### Test 1: Verify Notifications are Configured

```bash
# Check notification subscriptions
kubectl get application nginx-alb -n argocd -o jsonpath='{.metadata.annotations}' | grep notifications

# Check notification controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller --tail=50
```

### Test 2: Test with Invalid Image

1. Modify the NGINX version to an invalid value:
   ```bash
   cd ../k8s-manifests/nginx-alb/overlays/dev
   vi deployment-patch.yaml
   # Change NGINX_VERSION to "99.99-alpine" (invalid)
   ```

2. Commit and push to trigger ArgoCD sync

3. Expected behavior:
   - **With validation hook**: Sync will FAIL at PreSync phase, preventing deployment
   - **Without validation hook**: Sync succeeds, but you'll get a "degraded" notification when pods enter ImagePullBackOff

### Test 3: Monitor Application Health

```bash
# Watch application status
kubectl get application nginx-alb -n argocd -w

# Check pod status
kubectl get pods -n nginx-alb

# Describe pod to see image pull error
kubectl describe pod <pod-name> -n nginx-alb
```

---

## Notification Events

You will receive Slack notifications for:

| Event | Icon | Trigger |
|-------|------|---------|
| **Health Degraded** | :x: | Pods fail (ImagePullBackOff, CrashLoopBackOff, etc.) |
| **Sync Failed** | :warning: | ArgoCD cannot apply manifests |
| **Sync Running** | :arrows_counterclockwise: | Sync operation started |
| **Sync Succeeded** | :white_check_mark: | Manifests applied successfully |
| **Deployed** | :rocket: | Application is synced AND healthy |

---

## Troubleshooting

### No Notifications Received

1. Check notification controller:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller
   ```

2. Verify secret exists:
   ```bash
   kubectl get secret argocd-notifications-secret -n argocd
   ```

3. Test webhook manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test from ArgoCD"}' \
     YOUR_SLACK_WEBHOOK_URL
   ```

### Image Validation Hook Fails

1. Check hook job status:
   ```bash
   kubectl get jobs -n nginx-alb
   kubectl logs job/nginx-image-validator -n nginx-alb
   ```

2. Common issues:
   - Network connectivity to Docker Hub
   - Image registry authentication (if using private registry)
   - Wrong image tag format

### Application Stays Degraded

1. Check pod events:
   ```bash
   kubectl describe pod <pod-name> -n nginx-alb
   ```

2. Common causes:
   - Invalid image tag → Fix in `deployment-patch.yaml`
   - Resource limits → Check node resources
   - Configuration errors → Review ConfigMaps/Secrets

---

## Alternative Notification Channels

### Email Notifications

Add to `argocd-notifications-secret.yaml`:
```yaml
stringData:
  email-username: your-email@gmail.com
  email-password: your-app-password
```

Add to `argocd-notifications-cm.yaml`:
```yaml
data:
  service.email.gmail: |
    username: $email-username
    password: $email-password
    host: smtp.gmail.com
    port: 587
    from: $email-username
```

### Microsoft Teams

Add to `argocd-notifications-cm.yaml`:
```yaml
data:
  service.teams: |
    recipientUrls:
      argocd-alerts: https://your-tenant.webhook.office.com/webhookb2/...
```

---

## Best Practices

1. **Use validation hooks** to catch issues before deployment
2. **Set up multiple notification channels** (Slack + Email)
3. **Create dedicated Slack channels** for ArgoCD alerts
4. **Monitor hook execution time** to avoid slow syncs
5. **Keep NGINX_VERSION in sync** between hook and deployment patch
6. **Use revision history** to rollback quickly if needed

---

## Additional Resources

- [ArgoCD Notifications Documentation](https://argocd-notifications.readthedocs.io/)
- [Notification Triggers](https://argocd-notifications.readthedocs.io/en/stable/triggers/)
- [Notification Templates](https://argocd-notifications.readthedocs.io/en/stable/templates/)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
