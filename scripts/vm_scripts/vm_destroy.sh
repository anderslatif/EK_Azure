# Variables
# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

# Configuration file path
CONFIG_FILE="$(dirname "$0")/vm_config.sh"

# Check if variables are already defined, if not source or create config
if [ -z "$RG_NAME" ] || [ -z "$LOCATION" ] || [ -z "$VM_NAME" ] || [ -z "$ADMIN_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        # Config file exists, source it
        source "$CONFIG_FILE"
    else
        # Config file doesn't exist, prompt user and create it
        echo "Configuration file not found. Please provide the following details:"
        read -p "Resource Group Name [vmtest]: " RG_NAME
        RG_NAME=${RG_NAME:-vmtest}

        read -p "Location [spaincentral]: " LOCATION
        LOCATION=${LOCATION:-spaincentral}

        read -p "VM Name [vm1]: " VM_NAME
        VM_NAME=${VM_NAME:-vm1}

        read -p "Admin Username [adminuser]: " ADMIN_USER
        ADMIN_USER=${ADMIN_USER:-adminuser}

        read -p "SSH Key Path [~/.ssh/id_rsa.pub]: " SSH_KEY_PATH
        SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa.pub}

        # Create config file
        cat > "$CONFIG_FILE" <<EOF
# VM Configuration
RG_NAME="$RG_NAME"
LOCATION="$LOCATION"
VM_NAME="$VM_NAME"
ADMIN_USER="$ADMIN_USER"
SSH_KEY_PATH="$SSH_KEY_PATH"
EOF
        echo "Configuration saved to $CONFIG_FILE"
    fi
fi

# 1. Delete VM
az vm delete --resource-group $RG_NAME --name $VM_NAME --yes

# 2. Delete Resource Group
az group delete --name $RG_NAME --yes --no-wait
