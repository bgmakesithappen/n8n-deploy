#!/usr/bin/env python3
"""Quick n8n deployment script"""

import sys
import paramiko
import subprocess
from pathlib import Path
from colorama import init, Fore
import time

init(autoreset=True)

def get_n8n_ip():
    """Get n8n IP from terraform"""
    result = subprocess.run(
        ['terraform', 'output', '-raw', 'n8n_ip'],
        cwd=Path(__file__).parent.parent / 'terraform',
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()

def deploy_n8n():
    print(f"{Fore.CYAN}{'='*60}")
    print(f"{Fore.CYAN}n8n Deployment")
    print(f"{Fore.CYAN}{'='*60}\n")
    
    # Get IP
    host = get_n8n_ip()
    if not host:
        print(f"{Fore.RED}✗ Could not get IP from terraform")
        print(f"{Fore.YELLOW}  Run: cd terraform && terraform apply")
        return False
    
    print(f"{Fore.WHITE}Target: {host}")
    
    key_path = Path(__file__).parent.parent / 'terraform' / 'n8n-key.pem'
    env_path = Path(__file__).parent.parent / '.env'

    # Check for .env file
    if not env_path.exists():
        print(f"{Fore.RED}✗ Missing .env file")
        print(f"{Fore.YELLOW}  Create .env with: N8N_USER and N8N_PASSWORD")
        return False

    try:
        # Connect
        print(f"\n{Fore.YELLOW}→ Connecting...")
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        key = paramiko.RSAKey.from_private_key_file(str(key_path))
        client.connect(hostname=host, username='ubuntu', pkey=key, timeout=30)
        print(f"{Fore.GREEN}✓ Connected")
        
        # Create directory
        print(f"{Fore.YELLOW}→ Setting up directories...")
        stdin, stdout, stderr = client.exec_command('mkdir -p /home/ubuntu/n8n')
        stdout.channel.recv_exit_status()
        print(f"{Fore.GREEN}✓ Directories ready")
        
        # Upload docker-compose.yml
        print(f"{Fore.YELLOW}→ Uploading configuration...")
        sftp = client.open_sftp()
        
        local_compose = Path(__file__).parent.parent / 'services' / 'n8n' / 'docker-compose.yml'
        
        # Read, update webhook URL, write
        with open(local_compose, 'r') as f:
            compose_content = f.read()
        
        compose_content = compose_content.replace('PLACEHOLDER', host)
        
        # Write to remote
        with sftp.open('/home/ubuntu/n8n/docker-compose.yml', 'w') as f:
            f.write(compose_content)

        # Upload .env file
        with open(env_path, 'r') as f:
            env_content = f.read()
        with sftp.open('/home/ubuntu/n8n/.env', 'w') as f:
            f.write(env_content)

        sftp.close()
        print(f"{Fore.GREEN}✓ Configuration uploaded")
        
        # Pull image
        print(f"{Fore.YELLOW}→ Pulling n8n image (may take a minute)...")
        stdin, stdout, stderr = client.exec_command('cd /home/ubuntu/n8n && docker compose pull')
        stdout.channel.recv_exit_status()
        print(f"{Fore.GREEN}✓ Image pulled")
        
        # Start n8n
        print(f"{Fore.YELLOW}→ Starting n8n...")
        stdin, stdout, stderr = client.exec_command('cd /home/ubuntu/n8n && docker compose up -d')
        stdout.channel.recv_exit_status()
        print(f"{Fore.GREEN}✓ n8n started")
        
        # Wait for health
        print(f"{Fore.YELLOW}→ Waiting for n8n to be ready...")
        for i in range(12):  # 60 seconds total
            time.sleep(5)
            stdin, stdout, stderr = client.exec_command(
                'curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz'
            )
            status = stdout.read().decode().strip()
            if status == '200':
                print(f"{Fore.GREEN}✓ n8n is healthy!")
                break
            print(f"{Fore.YELLOW}  Still warming up... ({i+1}/12)")
        
        # Show status
        stdin, stdout, stderr = client.exec_command('docker ps --format "{{.Names}}: {{.Status}}"')
        output = stdout.read().decode()
        print(f"\n{Fore.CYAN}Container status:")
        print(f"{Fore.CYAN}  {output.strip()}")
        
        print(f"\n{Fore.GREEN}{'='*60}")
        print(f"{Fore.GREEN}✓ Deployment Complete!")
        print(f"{Fore.GREEN}{'='*60}\n")
        print(f"{Fore.WHITE}Access n8n at: {Fore.CYAN}http://{host}:5678")
        print(f"{Fore.WHITE}Login with credentials from your .env file")
        
        client.close()
        return True
        
    except Exception as e:
        print(f"\n{Fore.RED}✗ Deployment failed: {e}")
        return False

if __name__ == '__main__':
    success = deploy_n8n()
    sys.exit(0 if success else 1)
