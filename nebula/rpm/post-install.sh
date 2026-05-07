#!/bin/sh

# 1. Reload systemd so it sees the new nebula@.service template
# We check if we're in a systemd environment first to avoid errors in containers
if 
  test -d /run/systemd/system 
then
  systemctl daemon-reload >/dev/null 2>&1 || true
fi

# 2. Secure the config directory
# Nebula stores private keys; we want these permissions tight.
if 
  test -d /etc/nebula 
then
    chown root:root /etc/nebula
    chmod 750 /etc/nebula
fi

echo "Nebula installation complete."
echo "Templates and examples located in: /usr/share/doc/nebula/examples/"
echo "To start a mesh, add your config to /etc/nebula/<name>.yml and run:"
echo "  systemctl enable --now nebula@<name>"
