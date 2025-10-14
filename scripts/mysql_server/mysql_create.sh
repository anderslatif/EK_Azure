#!/bin/bash

# Source terminal colors and password function
source "$(dirname "$0")/../misc/terminal_colors.sh"
source "$(dirname "$0")/../misc/read_password.sh"

# Configuration file paths
CONFIG_FILE="$(dirname "$0")/mysql.config.sh"
AVAILABLE_REGIONS_CONFIG="$(dirname "$0")/../available_regions/available_regions.config.sh"

# Check if MySQL variables are already defined, if not source or create config
if [ -z "$RG_NAME" ] || [ -z "$LOCATION" ] || [ -z "$MYSQL_SERVER_NAME" ] || [ -z "$MYSQL_ADMIN_USER" ] || [ -z "$MYSQL_ADMIN_PASSWORD" ] || [ -z "$MYSQL_DB_NAME" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        # Config file exists, source it
        source "$CONFIG_FILE"
        # Also source available regions if exists
        [ -f "$AVAILABLE_REGIONS_CONFIG" ] && source "$AVAILABLE_REGIONS_CONFIG"
    else
        # Config file doesn't exist, show assumptions and prompt for confirmation
        printf "${BLUE}This script will create an Azure MySQL Flexible Server with the following configuration:${NC}\n"
        echo "  - SKU: Standard_B1ms (Burstable, 1 vCore, 2 GiB RAM)"
        echo "  - Tier: Burstable (Dev/Test - Free tier eligible)"
        echo "  - Storage: 20 GiB (The minimum)"
        echo ""

        # Prompt for confirmation
        read -p "Do you want to proceed with these settings? (y|yes): " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy](es)?$ ]]; then
            printf "${RED}Setup cancelled.${NC}\n"
            exit 0
        fi

        # Prompt user and create config
        echo ""
        echo "Configuration file not found. Please provide the following details:"

        read -p "Resource Group Name [mysql-server-rg]: " RG_NAME
        RG_NAME=${RG_NAME:-mysql-server-rg}

        while true; do
            read -p "MySQL Server Name (must be globally unique): " MYSQL_SERVER_NAME
            if [ -n "$MYSQL_SERVER_NAME" ]; then
                # Check if the MySQL server name is already taken
                printf "${BLUE}Checking availability of '$MYSQL_SERVER_NAME'...${NC}\n"
                if az mysql flexible-server show --name "$MYSQL_SERVER_NAME" --resource-group "$RG_NAME" 2>/dev/null | grep -q "name"; then
                    printf "${RED}MySQL server name '$MYSQL_SERVER_NAME' is already taken. Please choose another name.${NC}\n"
                else
                    printf "${GREEN}MySQL server name '$MYSQL_SERVER_NAME' is available.${NC}\n"
                    break
                fi
            else
                printf "${RED}MySQL Server Name cannot be empty.${NC}\n"
            fi
        done

        # Validate username
        RESERVED_USERNAMES=("azure_superuser" "admin" "administrator" "root" "guest" "sa" "public")
        while true; do
            read -p "MySQL Admin Username [adminuser]: " MYSQL_ADMIN_USER
            MYSQL_ADMIN_USER=${MYSQL_ADMIN_USER:-adminuser}

            # Trim leading/trailing spaces
            MYSQL_ADMIN_USER=$(echo "$MYSQL_ADMIN_USER" | xargs)

            # Check if username is in reserved list
            is_reserved=false
            for reserved in "${RESERVED_USERNAMES[@]}"; do
                if [ "$MYSQL_ADMIN_USER" = "$reserved" ]; then
                    is_reserved=true
                    break
                fi
            done

            if [ "$is_reserved" = true ]; then
                printf "${RED}Username '$MYSQL_ADMIN_USER' is reserved and cannot be used.${NC}\n"
                printf "${RED}Reserved names: azure_superuser, admin, administrator, root, guest, sa, public${NC}\n"
            elif [ ${#MYSQL_ADMIN_USER} -gt 32 ]; then
                printf "${RED}Username must be 32 characters or less (current: ${#MYSQL_ADMIN_USER}).${NC}\n"
            else
                printf "${GREEN}Username '$MYSQL_ADMIN_USER' is valid.${NC}\n"
                break
            fi
        done

        # Validate password
        while true; do
            read_password "MySQL Admin Password (8-128 chars, must include 3 of: uppercase, lowercase, numbers, special chars): " MYSQL_ADMIN_PASSWORD

            if [ -z "$MYSQL_ADMIN_PASSWORD" ]; then
                printf "${RED}Password cannot be empty.${NC}\n"
                continue
            fi

            # Check length
            pass_len=${#MYSQL_ADMIN_PASSWORD}
            if [ $pass_len -lt 8 ] || [ $pass_len -gt 128 ]; then
                printf "${RED}Password must be between 8 and 128 characters (current: $pass_len).${NC}\n"
                continue
            fi

            # Check character categories
            has_upper=0
            has_lower=0
            has_digit=0
            has_special=0

            if [[ "$MYSQL_ADMIN_PASSWORD" =~ [A-Z] ]]; then has_upper=1; fi
            if [[ "$MYSQL_ADMIN_PASSWORD" =~ [a-z] ]]; then has_lower=1; fi
            if [[ "$MYSQL_ADMIN_PASSWORD" =~ [0-9] ]]; then has_digit=1; fi
            # Check for special characters using glob patterns (more portable)
            if [[ "$MYSQL_ADMIN_PASSWORD" == *['!@#$%^&*()_+={}|:,./<>?~-']* ]] || \
               [[ "$MYSQL_ADMIN_PASSWORD" == *'['* ]] || [[ "$MYSQL_ADMIN_PASSWORD" == *']'* ]] || \
               [[ "$MYSQL_ADMIN_PASSWORD" == *';'* ]] || [[ "$MYSQL_ADMIN_PASSWORD" == *"'"* ]] || \
               [[ "$MYSQL_ADMIN_PASSWORD" == *'"'* ]] || [[ "$MYSQL_ADMIN_PASSWORD" == *'`'* ]]; then
                has_special=1
            fi

            category_count=$((has_upper + has_lower + has_digit + has_special))

            if [ $category_count -lt 3 ]; then
                printf "${RED}Password must contain characters from at least 3 of these categories:${NC}\n"
                printf "${RED}  - Uppercase letters (A-Z)${NC}\n"
                printf "${RED}  - Lowercase letters (a-z)${NC}\n"
                printf "${RED}  - Numbers (0-9)${NC}\n"
                printf "${RED}  - Special characters (!@#\$%%, etc.)${NC}\n"
                continue
            fi

            # Confirm password
            read_password "Confirm MySQL Admin Password: " MYSQL_ADMIN_PASSWORD_CONFIRM
            if [ "$MYSQL_ADMIN_PASSWORD" = "$MYSQL_ADMIN_PASSWORD_CONFIRM" ]; then
                printf "${GREEN}Password is valid.${NC}\n"
                break
            else
                printf "${RED}Passwords do not match. Please try again.${NC}\n"
            fi
        done

        read -p "MySQL Database Name [mydb]: " MYSQL_DB_NAME
        MYSQL_DB_NAME=${MYSQL_DB_NAME:-mydb}

        # Check if available regions config exists
        if [ -f "$AVAILABLE_REGIONS_CONFIG" ]; then
            # Load existing available regions
            source "$AVAILABLE_REGIONS_CONFIG"
        else
            # Get available regions
            printf "${BLUE}Fetching your available Azure regions...${NC} This will take several minutes but it will only be required the first time.\n"
            AVAILABLE_REGIONS_SCRIPT="$(dirname "$0")/../available_regions/available_regions.sh"
            AVAILABLE_REGIONS=()

            # Create temp file in a Windows-compatible way
            TEMP_FILE="${TMPDIR:-/tmp}/regions_$$_$RANDOM.txt"

            # Run the script with stderr shown (for progress) and stdout captured
            bash "$AVAILABLE_REGIONS_SCRIPT" > "$TEMP_FILE"

            # Read regions from temp file (strip carriage returns for Windows compatibility)
            while IFS= read -r region || [ -n "$region" ]; do
                region="${region%$'\r'}"  # Remove trailing \r if present
                [ -n "$region" ] && AVAILABLE_REGIONS+=("$region")
            done < "$TEMP_FILE"

            rm -f "$TEMP_FILE"

            # Save available regions to config file
            {
                echo "# Available Azure regions (cached)"
                echo "AVAILABLE_REGIONS=("
                for region in "${AVAILABLE_REGIONS[@]}"; do
                    echo "  \"$region\""
                done
                echo ")"
            } > "$AVAILABLE_REGIONS_CONFIG"
        fi

        # Display numbered list of regions
        printf "${GREEN}Available regions:${NC}\n"
        count=1
        for region in "${AVAILABLE_REGIONS[@]}"; do
            echo "$count. $region"
            ((count++))
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

        # Create config file (without password for security)
        {
            echo "# MySQL Configuration"
            echo "RG_NAME=\"$RG_NAME\""
            echo "LOCATION=\"$LOCATION\""
            echo "MYSQL_SERVER_NAME=\"$MYSQL_SERVER_NAME\""
            echo "MYSQL_ADMIN_USER=\"$MYSQL_ADMIN_USER\""
            echo "MYSQL_DB_NAME=\"$MYSQL_DB_NAME\""
            echo "# Note: Password not stored for security reasons"
        } > "$CONFIG_FILE"

        echo "Configuration saved to $CONFIG_FILE"
    fi
fi

# 1. Create Resource Group
printf "\n${GREEN}Creating resource group...${NC}\n"
az group create --name $RG_NAME --location $LOCATION

# 2. Create MySQL Flexible Server
printf "\n${GREEN}Creating MySQL Flexible Server...${NC}\n"
printf "${BLUE}Note: This will take several minutes.${NC}\n"
if ! az mysql flexible-server create \
  --name $MYSQL_SERVER_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --admin-user $MYSQL_ADMIN_USER \
  --admin-password "$MYSQL_ADMIN_PASSWORD" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 20 \
  --version 8.0.21 \
  --public-access 0.0.0.0-255.255.255.255; then
    printf "${RED}Failed to create MySQL Flexible Server.${NC}\n"
    exit 1
fi

# 3. Create Database
printf "\n${GREEN}Creating database...${NC}\n"
if ! az mysql flexible-server db create \
  --resource-group $RG_NAME \
  --server-name $MYSQL_SERVER_NAME \
  --database-name $MYSQL_DB_NAME; then
    printf "${RED}Failed to create database.${NC}\n"
    exit 1
fi

# 4. Configure firewall rules
printf "\n${GREEN}Configuring firewall rules...${NC}\n"

# Allow Azure services to access the server
printf "${BLUE}Allowing Azure services to access the database...${NC}\n"
az mysql flexible-server firewall-rule create \
  --resource-group $RG_NAME \
  --name $MYSQL_SERVER_NAME \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Get current public IP and add firewall rule
printf "${BLUE}Getting your current IP address...${NC}\n"
CURRENT_IP=$(curl -s https://api.ipify.org)
if [ -n "$CURRENT_IP" ]; then
    printf "${BLUE}Adding firewall rule for your IP: $CURRENT_IP${NC}\n"
    az mysql flexible-server firewall-rule create \
      --resource-group $RG_NAME \
      --name $MYSQL_SERVER_NAME \
      --rule-name AllowCurrentIP \
      --start-ip-address $CURRENT_IP \
      --end-ip-address $CURRENT_IP
    printf "${GREEN}Firewall rule added for IP: $CURRENT_IP${NC}\n"
else
    printf "${RED}Could not retrieve current IP address. You may need to add firewall rules manually.${NC}\n"
fi

# 5. Display connection information
printf "\n${GREEN}MySQL Flexible Server created successfully!${NC}\n"
printf "${BLUE}Server Name: $MYSQL_SERVER_NAME.mysql.database.azure.com${NC}\n"
printf "${BLUE}Admin User: $MYSQL_ADMIN_USER${NC}\n"
printf "${BLUE}Database Name: $MYSQL_DB_NAME${NC}\n"
printf "\n${GREEN}Connection string format:${NC}\n"
printf "jdbc:mysql://$MYSQL_SERVER_NAME.mysql.database.azure.com:3306/$MYSQL_DB_NAME?useSSL=true\n"
