#!/bin/bash

# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

# Display assumptions
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

# Configuration file paths
WEB_APP_CONFIG="$(dirname "$0")/web_app.config.sh"
CONFIG_FILE="$(dirname "$0")/mysql.config.sh"

# Check if web app config exists (to get resource group and location)
if [ ! -f "$WEB_APP_CONFIG" ]; then
    printf "${RED}Error: web_app.config.sh not found.${NC}\n"
    printf "Please run web_app.sh first to create the web app configuration.\n"
    exit 1
fi

# Source web app config to get RG_NAME and LOCATION
source "$WEB_APP_CONFIG"

# Check if MySQL variables are already defined, if not source or create config
if [ -z "$MYSQL_SERVER_NAME" ] || [ -z "$MYSQL_ADMIN_USER" ] || [ -z "$MYSQL_ADMIN_PASSWORD" ] || [ -z "$MYSQL_DB_NAME" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        # Config file exists, source it
        source "$CONFIG_FILE"
    else
        # Config file doesn't exist, prompt user and create it
        echo ""
        echo "Configuration file not found. Please provide the following details:"
        echo "Note: Using Resource Group '$RG_NAME' and Location '$LOCATION' from web_app.config.sh"
        echo ""

        while true; do
            read -p "MySQL Server Name (must be globally unique): " MYSQL_SERVER_NAME
            if [ -n "$MYSQL_SERVER_NAME" ]; then
                break
            else
                printf "${RED}MySQL Server Name cannot be empty.${NC}\n"
            fi
        done

        read -p "MySQL Admin Username [adminuser]: " MYSQL_ADMIN_USER
        MYSQL_ADMIN_USER=${MYSQL_ADMIN_USER:-adminuser}

        while true; do
            read -sp "MySQL Admin Password: " MYSQL_ADMIN_PASSWORD
            echo ""
            if [ -n "$MYSQL_ADMIN_PASSWORD" ]; then
                read -sp "Confirm MySQL Admin Password: " MYSQL_ADMIN_PASSWORD_CONFIRM
                echo ""
                if [ "$MYSQL_ADMIN_PASSWORD" = "$MYSQL_ADMIN_PASSWORD_CONFIRM" ]; then
                    break
                else
                    printf "${RED}Passwords do not match. Please try again.${NC}\n"
                fi
            else
                printf "${RED}Password cannot be empty.${NC}\n"
            fi
        done

        read -p "MySQL Database Name [mydb]: " MYSQL_DB_NAME
        MYSQL_DB_NAME=${MYSQL_DB_NAME:-mydb}

        # Create config file (without password for security)
        {
            echo "# MySQL Configuration"
            echo "MYSQL_SERVER_NAME=\"$MYSQL_SERVER_NAME\""
            echo "MYSQL_ADMIN_USER=\"$MYSQL_ADMIN_USER\""
            echo "MYSQL_DB_NAME=\"$MYSQL_DB_NAME\""
            echo "# Note: Password not stored for security reasons"
        } > "$CONFIG_FILE"

        echo "Configuration saved to $CONFIG_FILE"
    fi
fi

# 1. Create MySQL Flexible Server
printf "\n${GREEN}Creating MySQL Flexible Server...${NC}\n"
printf "${BLUE}Note: This may take several minutes.${NC}\n"
az mysql flexible-server create \
  --name $MYSQL_SERVER_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --admin-user $MYSQL_ADMIN_USER \
  --admin-password "$MYSQL_ADMIN_PASSWORD" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 20 \
  --version 8.0.21 \
  --public-access 0.0.0.0-255.255.255.255

# 2. Create Database
printf "\n${GREEN}Creating database...${NC}\n"
az mysql flexible-server db create \
  --resource-group $RG_NAME \
  --server-name $MYSQL_SERVER_NAME \
  --database-name $MYSQL_DB_NAME

# 3. Display connection information
printf "\n${GREEN}MySQL Flexible Server created successfully!${NC}\n"
printf "${BLUE}Server Name: $MYSQL_SERVER_NAME.mysql.database.azure.com${NC}\n"
printf "${BLUE}Database Name: $MYSQL_DB_NAME${NC}\n"
printf "${BLUE}Admin User: $MYSQL_ADMIN_USER${NC}\n"
printf "\n${GREEN}Connection string format:${NC}\n"
printf "jdbc:mysql://$MYSQL_SERVER_NAME.mysql.database.azure.com:3306/$MYSQL_DB_NAME?useSSL=true\n"

echo "\n"
echo -e "${GREEN}Try connecting to the database using the following command:${NC}"
echo -e "${BLUE}mysql -h $MYSQL_SERVER_NAME.mysql.database.azure.com -u $MYSQL_ADMIN_USER -p $MYSQL_DB_NAME${NC}"

