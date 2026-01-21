#!/bin/bash
# n8n management commands

case "$1" in
  deploy)
    echo "Creating infrastructure..."
    cd terraform && terraform apply -auto-approve
    echo "Waiting for instance to initialize (2 minutes)..."
    sleep 120
    cd ..
    echo "Deploying n8n..."
    python3 scripts/deploy.py
    ;;
    
  redeploy)
    echo "Redeploying n8n (keeps data)..."
    python3 scripts/deploy.py
    ;;
    
  destroy)
    echo "WARNING: This will destroy the instance AND ALL DATA!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
      cd terraform && terraform destroy -auto-approve
    fi
    ;;
    
  ssh)
    cd terraform
    IP=$(terraform output -raw n8n_ip)
    ssh -i n8n-key.pem ubuntu@$IP
    ;;
    
  logs)
    cd terraform
    IP=$(terraform output -raw n8n_ip)
    ssh -i n8n-key.pem ubuntu@$IP 'cd n8n && docker compose logs -f'
    ;;
    
  backup)
    cd terraform
    IP=$(terraform output -raw n8n_ip)
    BACKUP_FILE="n8n-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    echo "Creating backup..."
    ssh -i n8n-key.pem ubuntu@$IP 'cd n8n && tar czf - n8n-data' > $BACKUP_FILE
    echo "Backup saved: $BACKUP_FILE"
    ;;
    
  restore)
    if [ -z "$2" ]; then
      echo "Usage: ./commands.sh restore <backup-file>"
      exit 1
    fi
    cd terraform
    IP=$(terraform output -raw n8n_ip)
    echo "Restoring from $2..."
    cat $2 | ssh -i n8n-key.pem ubuntu@$IP 'cd n8n && tar xzf -'
    echo "Restarting n8n..."
    ssh -i n8n-key.pem ubuntu@$IP 'cd n8n && docker compose restart'
    echo "Restore complete!"
    ;;
    
  url)
    cd terraform
    terraform output n8n_url
    ;;
    
  *)
    echo "n8n Deployment Commands:"
    echo "  ./commands.sh deploy     - Create infrastructure and deploy n8n"
    echo "  ./commands.sh redeploy   - Redeploy n8n (keeps data)"
    echo "  ./commands.sh destroy    - Destroy everything (WARNING: deletes data)"
    echo "  ./commands.sh ssh        - SSH into instance"
    echo "  ./commands.sh logs       - View n8n logs"
    echo "  ./commands.sh backup     - Backup n8n data"
    echo "  ./commands.sh restore    - Restore from backup"
    echo "  ./commands.sh url        - Show n8n URL"
    ;;
esac
