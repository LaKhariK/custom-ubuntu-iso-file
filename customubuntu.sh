# Update and upgrade Ubuntu packages
sudo apt update 
sudo apt upgrade 

# Install required packages for device management,
# Active Directory integration, TPM support, and encryption tools
sudo apt install landscape-client curl sssd-ad sssd-tools realmd adcli tpm2-tools tss2 dracut libcurl4 libjson-c5 libtss2-fapi1 libtss2-tcti-cmd0 libtss2-tcti-device0 libtss2-tcti-mssim0 libtss2-tcti-swtpm0

# Install internal company certificate bundle
sudo curl -LksS https://company.example.com/path/to/install-ca-certs | sh

# Prompt for computer name
read -p "What is your computer name?: " COMPUTER_TITLE
COMPUTER_TITLE="${COMPUTER_TITLE//[$'\n\t\r']}"

# Prompt for admin account name
read -p "What is your admin account name?: " COMPUTER_USERNAME
COMPUTER_USERNAME="${COMPUTER_USERNAME//[$'\n\t\r']}"

# Retrieve Landscape token
landscapeToken=$(sudo cat /root/landscape.txt)

# Configure Ubuntu Landscape management client
sudo landscape-config \
--computer-title $COMPUTER_TITLE \
--account-name standalone \
-p $landscapeToken \
--url https://landscape-server.example.com/message-system \
--ping-url http://landscape-server.example.com/ping

# Navigate to VPN installer directory
cd ~/VPNClient/VPNClient-Version

# Install VPN software
./vpn_install.sh

# Install endpoint security software
sudo /root/SecurityAgentInstall.sh


# ---------------- Google Chrome ----------------

# Download Chrome package
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# Install Chrome
sudo dpkg -i google-chrome-stable_current_amd64.deb


# ---------------- Active Directory ----------------

# Join machine to enterprise domain
sudo realm join -U $COMPUTER_USERNAME -v example.com

# Automatically create home directories
sudo pam-auth-update --enable mkhomedir

# Prompt for end user account
read -p "What is the end-user name?: " END_USER
END_USER="${END_USER//[$'\n\t\r']}"

# Add end user to sudo group
sudo usermod -a -G sudo "$END_USER"


# ---------------- Chrome Management ----------------

# Create policy directory
sudo mkdir -p /etc/opt/chrome/policies/enrollment

cd /etc/opt/chrome/policies/enrollment

# Add cloud enrollment token
echo "REPLACE-WITH-CHROME-ENROLLMENT-TOKEN" | sudo tee ./CloudManagementEnrollmentToken

# Enable mandatory enrollment
echo "Mandatory" | sudo tee ./CloudManagementEnrollmentOptions

# Remove extra newline characters
sudo truncate -s -1 ./CloudManagementEnrollmentToken 
sudo truncate -s -1 ./CloudManagementEnrollmentOptions


# ---------------- Landscape Script Permissions ----------------

# Allow script execution plugins
echo "include_manager_plugins = ScriptExecution" | sudo tee -a /etc/landscape/client.conf

# Specify users allowed to execute scripts
echo "script_users = root,landscape,nobody" | sudo tee -a /etc/landscape/client.conf


# ---------------- TPM + Encryption ----------------

# Retrieve encrypted partition UUID
UUID=$(awk '{print $2}' /etc/crypttab | cut -d= -f2)

# Configure TPM auto unlock
echo "dm_crypt-0 UUID=${UUID} none tpm2-device=auto,luks,discard" | sudo tee /etc/crypttab 

# Enable TPM module for Dracut
echo "add_dracutmodules+= \" tpm2-tss \"" | sudo tee /etc/dracut.conf.d/tpm2.conf

# Generate host-specific initramfs
echo "hostonly=\"yes\"" | sudo tee -a /etc/dracut.conf.d/tpm2.conf

# Bind encrypted drive to TPM
sudo systemd-cryptenroll \
--tpm2-device=auto \
--tpm2-pcrs="0+7" \
/dev/nvme0n1p3 

# Rebuild boot image
sudo dracut -f --regenerate-all


# ---------------- Kernel Installation ----------------

# Grab newest kernel package links
pac1="https://kernel.ubuntu.com/mainline/v6.12/$(curl https://kernel.ubuntu.com/mainline/v6.12/ | grep -e ">amd.*deb" -o | head -n1 | tail -1 | sed 's/^.//')"

pac2="https://kernel.ubuntu.com/mainline/v6.12/$(curl https://kernel.ubuntu.com/mainline/v6.12/ | grep -e ">amd.*deb" -o | head -n2 | tail -1 | sed 's/^.//')"

pac3="https://kernel.ubuntu.com/mainline/v6.12/$(curl https://kernel.ubuntu.com/mainline/v6.12/ | grep -e ">amd.*deb" -o | head -n3 | tail -1 | sed 's/^.//')"

pac4="https://kernel.ubuntu.com/mainline/v6.12/$(curl https://kernel.ubuntu.com/mainline/v6.12/ | grep -e ">amd.*deb" -o | head -n4 | tail -1 | sed 's/^.//')"

# Download packages
wget $pac1
wget $pac2 
wget $pac3
wget $pac4

# Install kernel packages
sudo dpkg -i $(echo $pac1 | grep "linux.*" -o)
sudo dpkg -i $(echo $pac2 | grep "linux.*" -o)
sudo dpkg -i $(echo $pac3 | grep "linux.*" -o)
sudo dpkg -i $(echo $pac4 | grep "linux.*" -o)

echo "Setup complete."
