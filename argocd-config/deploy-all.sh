#!/bin/bash

# Complete ArgoCD Notifications Setup with SMTP Relay
# Author: Jian Ouyang (jian.ouyang@sapns2.com)

set -e

NAMESPACE="argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "ArgoCD Notifications Complete Setup"
echo "======================================"
echo ""
echo "This will deploy:"
echo "1. SMTP Relay (via ArgoCD)"
echo "2. Notification ConfigMap"
echo "3. Notification Secret"
echo "4. Enhanced nginx-alb application"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
fi

echo ""
echo "======================================"
echo "Step 1: Deploy SMTP Relay via ArgoCD"
echo "======================================"

# Apply SMTP relay ArgoCD application
echo "Applying SMTP relay ArgoCD application..."
kubectl apply -f "$SCRIPT_DIR/../argocd-apps/smtp-relay-app.yaml"

echo "Waiting for ArgoCD to sync..."
sleep 5

# Wait for application to sync
echo "Waiting for SMTP relay to be deployed..."
for i in {1..30}; do
    if kubectl get pods -n "$NAMESPACE" -l app=smtp-relay 2>/dev/null | grep -q Running; then
        echo "✓ SMTP relay pod is running"
        break
    fi
    echo "  Waiting for SMTP relay pod... ($i/30)"
    sleep 2
done

# Verify SMTP relay is ready
kubectl wait --for=condition=ready pod -l app=smtp-relay -n "$NAMESPACE" --timeout=60s || {
    echo "⚠️  SMTP relay pod not ready yet, but continuing..."
    echo "   Check status with: kubectl get pods -n argocd -l app=smtp-relay"
}

echo ""
echo "======================================"
echo "Step 2: Apply Notification Secret"
echo "======================================"

# Apply notification secret
kubectl apply -f "$SCRIPT_DIR/argocd-notifications-secret.yaml"
echo "✓ Notification secret applied"

echo ""
echo "======================================"
echo "Step 3: Apply Notification ConfigMap"
echo "======================================"

# Apply notification ConfigMap
kubectl apply -f "$SCRIPT_DIR/argocd-notifications-cm.yaml"
echo "✓ Notification ConfigMap applied"

# Prompt for ArgoCD URL
read -p "Enter your ArgoCD URL (or press Enter for default 'https://argocd.example.com'): " ARGOCD_URL
if [ -z "$ARGOCD_URL" ]; then
    ARGOCD_URL="https://argocd.example.com"
fi

# Update ArgoCD URL in context
kubectl patch configmap argocd-notifications-cm -n "$NAMESPACE" --type merge -p "{
  \"data\": {
    \"context\": \"argocdUrl: $ARGOCD_URL\"
  }
}"
echo "✓ ArgoCD URL context updated: $ARGOCD_URL"

echo ""
echo "======================================"
echo "Step 4: Apply Enhanced Application"
echo "======================================"

read -p "Do you want to update the nginx-alb application with notifications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup current application
    if kubectl get application nginx-alb -n "$NAMESPACE" &>/dev/null; then
        kubectl get application nginx-alb -n "$NAMESPACE" -o yaml > "$SCRIPT_DIR/nginx-alb-app-backup-$(date +%Y%m%d-%H%M%S).yaml"
        echo "✓ Backup created"
    fi

    # Apply enhanced application
    kubectl apply -f "$SCRIPT_DIR/../argocd-apps/nginx-alb-app-enhanced.yaml"
    echo "✓ Application updated with notification annotations"
else
    echo "Skipping application update"
fi

echo ""
echo "======================================"
echo "Step 5: Verify Setup"
echo "======================================"

echo ""
echo "SMTP Relay Status:"
kubectl get pods -n "$NAMESPACE" -l app=smtp-relay
kubectl get svc smtp-relay -n "$NAMESPACE"

echo ""
echo "ArgoCD Applications:"
kubectl get applications -n "$NAMESPACE" | grep -E "NAME|smtp-relay|nginx-alb"

echo ""
echo "Notification Controller:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-notifications-controller

echo ""
echo "======================================"
echo "Setup Complete! ✅"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Verify SMTP relay is healthy:"
echo "   kubectl logs -l app=smtp-relay -n argocd"
echo ""
echo "2. Check notification controller:"
echo "   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller"
echo ""
echo "3. Test with invalid image:"
echo "   cd k8s-manifests/nginx-alb/overlays/dev"
echo "   # Edit deployment-patch.yaml: NGINX_VERSION: '99.99-alpine'"
echo "   # Commit and push"
echo ""
echo "4. Watch for email in Slack channel:"
echo "   jian-private-aaaaq6nbninfp6bphtpr3pwl7m@sap.org.slack.com"
echo ""
echo "For more information:"
echo "  - Full guide: $SCRIPT_DIR/SETUP-SMTP-RELAY.md"
echo "  - Quick ref: $SCRIPT_DIR/QUICK-REFERENCE.md"
echo ""
