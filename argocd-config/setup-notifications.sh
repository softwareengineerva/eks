#!/bin/bash

# ArgoCD Notifications Setup Script
# Author: Jian Ouyang (jian.ouyang@sapns2.com)

set -e

NAMESPACE="argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "ArgoCD Notifications Setup"
echo "======================================"
echo ""

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl is not installed or not in PATH"
        exit 1
    fi
    echo "✓ kubectl found"
}

# Function to check if ArgoCD is installed
check_argocd() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo "❌ ArgoCD namespace '$NAMESPACE' not found"
        echo "   Please install ArgoCD first"
        exit 1
    fi
    echo "✓ ArgoCD namespace found"
}

# Function to check if notifications controller is running
check_notifications_controller() {
    if ! kubectl get deploy argocd-notifications-controller -n "$NAMESPACE" &> /dev/null; then
        echo "⚠️  ArgoCD notifications controller not found"
        read -p "   Do you want to install it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "   Installing notifications controller..."
            kubectl apply -n "$NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
            echo "✓ Notifications controller installed"
        else
            echo "   Skipping installation"
        fi
    else
        echo "✓ Notifications controller found"
    fi
}

# Function to prompt for Slack webhook
configure_slack_webhook() {
    echo ""
    echo "======================================"
    echo "Slack Webhook Configuration"
    echo "======================================"
    echo "Get your Slack webhook URL from:"
    echo "https://api.slack.com/messaging/webhooks"
    echo ""

    # Check if secret already exists
    if kubectl get secret argocd-notifications-secret -n "$NAMESPACE" &> /dev/null; then
        echo "⚠️  Secret 'argocd-notifications-secret' already exists"
        read -p "   Do you want to update it? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "   Skipping secret configuration"
            return
        fi
    fi

    read -p "Enter your Slack webhook URL (or press Enter to use template): " WEBHOOK_URL

    if [ -z "$WEBHOOK_URL" ]; then
        echo "   Using template webhook URL (you'll need to update it later)"
        kubectl apply -f "$SCRIPT_DIR/argocd-notifications-secret.yaml"
    else
        # Create secret with provided webhook URL
        kubectl create secret generic argocd-notifications-secret \
            -n "$NAMESPACE" \
            --from-literal=slack-token="$WEBHOOK_URL" \
            --dry-run=client -o yaml | kubectl apply -f -
        echo "✓ Secret created with your webhook URL"
    fi
}

# Function to apply notification ConfigMap
apply_notification_config() {
    echo ""
    echo "======================================"
    echo "Notification ConfigMap"
    echo "======================================"

    # Prompt for ArgoCD URL
    read -p "Enter your ArgoCD URL (e.g., https://argocd.example.com): " ARGOCD_URL

    if [ -z "$ARGOCD_URL" ]; then
        ARGOCD_URL="https://argocd.example.com"
        echo "   Using default URL: $ARGOCD_URL"
    fi

    # Apply ConfigMap
    kubectl apply -f "$SCRIPT_DIR/argocd-notifications-cm.yaml"

    # Update ArgoCD URL in context
    kubectl patch configmap argocd-notifications-cm -n "$NAMESPACE" --type merge -p "{
      \"data\": {
        \"context\": \"argocdUrl: $ARGOCD_URL\"
      }
    }"

    echo "✓ Notification ConfigMap applied"
}

# Function to update application with notifications
update_application() {
    echo ""
    echo "======================================"
    echo "Update Application"
    echo "======================================"
    echo "This will update the nginx-alb application with notification annotations"

    read -p "Do you want to update the nginx-alb application? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Backup current application
        kubectl get application nginx-alb -n "$NAMESPACE" -o yaml > "$SCRIPT_DIR/nginx-alb-app-backup-$(date +%Y%m%d-%H%M%S).yaml"
        echo "   ✓ Backup created"

        # Apply enhanced application
        kubectl apply -f "$SCRIPT_DIR/../argocd-apps/nginx-alb-app-enhanced.yaml"
        echo "   ✓ Application updated"
    else
        echo "   Skipping application update"
        echo "   You can manually apply: kubectl apply -f ../argocd-apps/nginx-alb-app-enhanced.yaml"
    fi
}

# Function to enable image validation hook
enable_validation_hook() {
    echo ""
    echo "======================================"
    echo "Image Validation Hook"
    echo "======================================"
    echo "This adds a pre-sync hook to validate Docker images before deployment"

    read -p "Do you want to enable image validation hook? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        KUSTOMIZATION_FILE="$SCRIPT_DIR/../k8s-manifests/nginx-alb/base/kustomization.yaml"

        # Check if already added
        if grep -q "image-validation-hook-secure.yaml" "$KUSTOMIZATION_FILE"; then
            echo "   ⚠️  Validation hook already added to kustomization.yaml"
        else
            # Add validation hook to resources
            cp "$KUSTOMIZATION_FILE" "$KUSTOMIZATION_FILE.bak"
            cat >> "$KUSTOMIZATION_FILE" << 'EOF'
  - image-validation-hook-secure.yaml
EOF
            echo "   ✓ Validation hook added to kustomization.yaml"
            echo "   Note: You'll need to commit and push this change for ArgoCD to pick it up"
        fi
    else
        echo "   Skipping validation hook"
    fi
}

# Function to test notification setup
test_notifications() {
    echo ""
    echo "======================================"
    echo "Test Notifications"
    echo "======================================"

    read -p "Do you want to test the notification setup? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Checking notification controller logs..."
        kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-notifications-controller --tail=20

        echo ""
        echo "Application notification subscriptions:"
        kubectl get application nginx-alb -n "$NAMESPACE" -o jsonpath='{.metadata.annotations}' | grep notifications || echo "No subscriptions found"
    fi
}

# Main execution
main() {
    check_kubectl
    check_argocd
    check_notifications_controller
    configure_slack_webhook
    apply_notification_config
    update_application
    enable_validation_hook
    test_notifications

    echo ""
    echo "======================================"
    echo "Setup Complete!"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo "1. Verify Slack webhook is working by checking your Slack channel"
    echo "2. Test with an invalid image version to trigger degraded notification"
    echo "3. Check logs: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller"
    echo ""
    echo "For more information, see: $SCRIPT_DIR/README.md"
}

# Run main function
main
