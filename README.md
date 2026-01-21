# n8n Rapid Deployment

Single-command deployment of n8n with persistent storage.

## Quick Start
```bash
# 1. Update your IP in terraform/main.tf (2 places)
# 2. Get current Ubuntu AMI and update terraform/main.tf
# 3. Deploy
./commands.sh deploy

# Access at http://YOUR_IP:5678
# Default: admin / ChangeMe123!
```

## Commands
```bash
./commands.sh deploy      # Full deployment (~5 min)
./commands.sh redeploy    # Update n8n (keeps data)
./commands.sh backup      # Backup all workflows/credentials
./commands.sh restore <file>  # Restore from backup
./commands.sh logs        # View logs
./commands.sh ssh         # SSH into instance
./commands.sh destroy     # Destroy everything
```

## Data Persistence

All workflows and credentials are stored in `n8n-data/` volume.
This persists across:
- Container restarts
- n8n updates/redeployments
- Instance reboots

**Backups are YOUR responsibility** - run `./commands.sh backup` regularly!

## Cost

- t3.small: ~$15/month if running 24/7
- Stop when not in use: ~$1/month (storage only)

## Updating n8n
```bash
./commands.sh ssh
cd n8n
docker compose pull
docker compose up -d
```
