#!/bin/bash

# Get the DNS name from the first argument
DNS_NAME=$1

# Check if the DNS name was provided
if [ -z "$DNS_NAME" ]; then
  echo "Usage: $0 <dns-name>"
  exit 1
fi

# Resolve the IP address
HOME_SERVER_IP=$(dig +short "$DNS_NAME")

# Check if resolution was successful
if [ -z "$HOME_SERVER_IP" ]; then
  echo "Failed to resolve DNS: $DNS_NAME"
  exit 1
fi

# Azure Login (ensure you pass Azure credentials securely, e.g., via environment variables)
az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID"

# Check if the container group exists
CONTAINER_GROUP_EXISTS=$(az container show \
    --resource-group homelabrg-resource-group \
    --name "homelabrg-containergroup" \
    --query "name" \
    --output tsv 2>/dev/null)

# Get the current environment variable from the container group if it exists
if [ -n "$CONTAINER_GROUP_EXISTS" ]; then
  CURRENT_IP=$(az container show \
      --resource-group homelabrg-resource-group \
      --name "homelabrg-containergroup" \
      --query "containers[0].environmentVariables[?name=='YOUR_HOME_SERVER_PUBLIC_IP'].value" \
      --output tsv)
else
  echo "Container group 'homelabrg-containergroup' does not exist. It will be created."
fi

# Check if the IP has changed
if [ "$HOME_SERVER_IP" != "$CURRENT_IP" ]; then
  echo "Changing IP from $CURRENT_IP to $HOME_SERVER_IP"

  # Delete the existing container group if it exists
  if [ -n "$CONTAINER_GROUP_EXISTS" ]; then
    az container delete \
        --resource-group homelabrg-resource-group \
        --name "homelabrg-containergroup" \
        --yes
  fi

  # Create a new container group with the updated environment variable and os type
    az container create \
    --resource-group homelabrg-resource-group \
    --name "homelabrg-containergroup" \
    --image "public.ecr.aws/nginx/nginx:latest" \
    --cpu "0.5" \
    --memory "1.5" \
    --environment-variables YOUR_HOME_SERVER_PUBLIC_IP="$HOME_SERVER_IP" \
    --ports 80 443 \
    --os-type Linux \
    --vnet "westus2-dev-homelabrg-vnet" \
    --subnet "homelabrgSubnet" \
    --command-line "/bin/sh -c 'mkdir -p /etc/nginx/conf.d/ && \
    echo \"server {\" > /etc/nginx/conf.d/default.conf.template && \
    echo \"    listen 80;\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"    location / {\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"        return 301 https://\"$\"host\"$\"request_uri;\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"    }\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"}\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"server {\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"    listen 443;\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"    location / {\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"        proxy_pass http://\$YOUR_HOME_SERVER_PUBLIC_IP;\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"        proxy_set_header Host \"$\"host;\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"        proxy_set_header X-Real-IP \"$\"remote_addr;\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"        proxy_set_header X-Forwarded-For \"$\"proxy_add_x_forwarded_for;\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"    }\" >> /etc/nginx/conf.d/default.conf.template && \
    echo \"}\" >> /etc/nginx/conf.d/default.conf.template && \
    nginx -g \"'\"daemon off;\"'\"'"


  echo "Rebuilt container group with new IP: $HOME_SERVER_IP"
else
  echo "IP address has not changed. No rebuild required."
fi
