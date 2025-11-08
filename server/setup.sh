#!/bin/bash

# Update packages and install necessary dependencies
echo "Updating packages..."
sudo apt-get update -y
sudo apt-get install -y curl gnupg2 software-properties-common

# Install K3s
echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -

# Set the kubeconfig file path for kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Verify K3s installation
if ! kubectl get nodes; then
    echo "K3s installation failed!"
    exit 1
fi

# Install Docker Registry
echo "Setting up Docker Registry..."
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Verify Docker Registry is running
if ! docker ps | grep -q registry; then
    echo "Docker Registry is not running!"
    exit 1
fi

# Install Moon (Assuming Moon is a tool with installation commands)
echo "Installing Moon..."
# Example installation command; replace with the actual command:
# curl -sL <installation_url> | bash

# Install Chrome browser images (Assuming Docker images for Chrome)
echo "Pulling Chrome browser images..."
docker pull selenium/standalone-chrome

echo "Setup completed successfully!"