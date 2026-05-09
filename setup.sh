#!/bin/bash

echo "What would you like to do?"
echo "1) Configure UFW firewall (allow ports 80, 443, 22)"
echo "2) Add SSH public key for root login"
echo "3) Change swap file size"
echo "4) Set DNS servers to 1.1.1.1 and 8.8.8.8"
echo "5) Set Docker DNS to 1.1.1.1 and 8.8.8.8"
echo ""
read -p "Enter your choice [1-5]: " choice

case "$choice" in
  1)
    echo "Configuring UFW..."
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw allow 22
    sudo ufw --force enable
    sudo ufw status
    ;;
  2)
    echo "Paste your public key below and press Enter, then Ctrl+D:"
    key=$(cat)

    if [ -z "$key" ]; then
      echo "No key provided. Exiting."
      exit 1
    fi

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "$key" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "Public key added to /root/.ssh/authorized_keys"

    echo "Updating /etc/ssh/sshd_config..."
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # Uncomment PubkeyAuthentication yes
    sed -i 's/^#\s*PubkeyAuthentication yes/PubkeyAuthentication yes/' "$SSHD_CONFIG"

    # Ensure AuthorizedKeysFile is uncommented with correct value
    if grep -qE '^\s*#\s*AuthorizedKeysFile' "$SSHD_CONFIG"; then
      sed -i 's/^\s*#\s*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' "$SSHD_CONFIG"
    elif ! grep -qE '^\s*AuthorizedKeysFile' "$SSHD_CONFIG"; then
      echo "AuthorizedKeysFile .ssh/authorized_keys" >> "$SSHD_CONFIG"
    fi

    # Disable password authentication
    read -p "Disable password authentication? (recommended) [y/N]: " disable_pass
    if [[ "$disable_pass" =~ ^[Yy]$ ]]; then
      sed -i 's/^\s*#\s*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
      sed -i 's/^\s*PasswordAuthentication yes/PasswordAuthentication no/' "$SSHD_CONFIG"
      echo "Password authentication disabled."
    fi

    echo "Restarting SSH service..."
    systemctl restart sshd
    echo "Done."
    ;;
  3)
    read -p "Enter desired swap size (e.g. 2G, 512M): " swapsize
    if [ -z "$swapsize" ]; then
      echo "No size provided. Exiting."
      exit 1
    fi
    echo "Configuring ${swapsize} swap file..."
    sudo swapoff /swapfile
    sudo rm /swapfile
    sudo fallocate -l "$swapsize" /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "Swap configured:"
    swapon --show
    ;;
  4)
    echo "Setting DNS servers to 1.1.1.1 and 8.8.8.8..."
    RESOLV="/etc/resolv.conf"
    sudo chattr -i "$RESOLV" 2>/dev/null
    echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee "$RESOLV" > /dev/null
    sudo chattr +i "$RESOLV"
    echo "DNS configured:"
    cat "$RESOLV"
    ;;
  5)
    echo "Configuring Docker DNS..."
    sudo mkdir -p /etc/docker
    echo '{
      "dns": ["1.1.1.1", "8.8.8.8"],
      "mtu": 1400
    }' | sudo tee /etc/docker/daemon.json > /dev/null
    sudo systemctl restart docker
    echo "Docker DNS configured."
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac
