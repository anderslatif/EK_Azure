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

        read -p "VM Name [vm1]: " VM_NAME
        VM_NAME=${VM_NAME:-vm1}

        read -p "Admin Username [adminuser]: " ADMIN_USER
        ADMIN_USER=${ADMIN_USER:-adminuser}

        read -p "SSH Key Path [~/.ssh/id_rsa.pub]: " SSH_KEY_PATH
        SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa.pub}

        # Get available regions (last prompt before deployment)
        printf "${BLUE}Fetching your available Azure regions...${NC} This will take several minutes but it will only be required the first time.\n"
        AVAILABLE_REGIONS_SCRIPT="$(dirname "$0")/../available_regions/available_regions.sh"
        AVAILABLE_REGIONS=()
        TEMP_REGIONS=$(bash "$AVAILABLE_REGIONS_SCRIPT")
        while IFS= read -r region; do
            [ -n "$region" ] && AVAILABLE_REGIONS+=("$region")
        done <<< "$TEMP_REGIONS"

        # Display numbered list of regions
        printf "${GREEN}Available regions:${NC}\n"
        for i in "${!AVAILABLE_REGIONS[@]}"; do
            echo "$((i+1)). ${AVAILABLE_REGIONS[$i]}"
        done

        # Prompt user to select a region
        while true; do
            read -p "Select region number: " REGION_NUM
            if [[ "$REGION_NUM" =~ ^[0-9]+$ ]] && [ "$REGION_NUM" -ge 1 ] && [ "$REGION_NUM" -le "${#AVAILABLE_REGIONS[@]}" ]; then
                LOCATION="${AVAILABLE_REGIONS[$((REGION_NUM-1))]}"
                break
            else
                printf "${RED}Invalid selection. Please enter a number between 1 and ${#AVAILABLE_REGIONS[@]}${NC}\n"
            fi
        done

        # Create config file with available regions list
        {
            echo "# VM Configuration"
            echo "RG_NAME=\"$RG_NAME\""
            echo "LOCATION=\"$LOCATION\""
            echo "VM_NAME=\"$VM_NAME\""
            echo "ADMIN_USER=\"$ADMIN_USER\""
            echo "SSH_KEY_PATH=\"$SSH_KEY_PATH\""
            echo ""
            echo "# Available regions"
            echo "AVAILABLE_REGIONS=("
            for region in "${AVAILABLE_REGIONS[@]}"; do
                echo "  \"$region\""
            done
            echo ")"
        } > "$CONFIG_FILE"

        echo "Configuration saved to $CONFIG_FILE"
    fi
fi

# 1. Create Resource Group
az group create --name $RG_NAME --location $LOCATION
 
# 2. Create VM
# Expand tilde in SSH key path for Windows compatibility
EXPANDED_SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
az vm create \
  --resource-group $RG_NAME \
  --name $VM_NAME \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username $ADMIN_USER \
  --public-ip-sku Standard \
  --authentication-type ssh \
  --ssh-key-values "$EXPANDED_SSH_KEY_PATH" \
  --output table
 
# 3. Open SSH port
az vm open-port --resource-group $RG_NAME --name $VM_NAME --port 22

# 4. Get VM IP address and print SSH command
VM_IP=$(az vm show --resource-group $RG_NAME --name $VM_NAME --show-details --query publicIps --output tsv)
printf "${GREEN}SSH command:${NC}\n"
printf "${BLUE}ssh $ADMIN_USER@$VM_IP${NC}\n"
