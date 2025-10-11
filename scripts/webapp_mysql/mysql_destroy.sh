#!/bin/bash

# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

# Configuration file paths
WEB_APP_CONFIG="$(dirname "$0")/web_app.config.sh"
CONFIG_FILE="$(dirname "$0")/mysql.config.sh"

# Check if web app config exists (to get resource group)
if [ ! -f "$WEB_APP_CONFIG" ]; then
    printf "${RED}Error: web_app.config.sh not found.${NC}\n"
    exit 1
fi

# Source web app config to get RG_NAME
source "$WEB_APP_CONFIG"

# Check if MySQL config exists and source it
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    printf "${RED}Configuration file not found at $CONFIG_FILE${NC}\n"
    printf "Please run mysql_create.sh first to create the configuration.\n"
    exit 1
fi

# Verify required variables are set
if [ -z "$MYSQL_SERVER_NAME" ]; then
    printf "${RED}Error: MySQL server name not found in configuration.${NC}\n"
    exit 1
fi

if [ -z "$RG_NAME" ]; then
    printf "${RED}Error: Resource group name not found in configuration.${NC}\n"
    exit 1
fi

# Display what will be deleted
printf "${BLUE}This will delete the following Azure resources:${NC}\n"
echo "  - MySQL Flexible Server: $MYSQL_SERVER_NAME"
echo "  - All databases within this server (including $MYSQL_DB_NAME)"
echo "  - Resource Group: $RG_NAME (will remain intact)"
echo ""

# Prompt for confirmation
read -p "Are you sure you want to delete the MySQL server? (y|yes): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy](es)?$ ]]; then
    printf "${RED}Deletion cancelled.${NC}\n"
    exit 0
fi

# Delete MySQL Flexible Server
printf "\n${GREEN}Deleting MySQL Flexible Server...${NC}\n"
az mysql flexible-server delete \
  --resource-group $RG_NAME \
  --name $MYSQL_SERVER_NAME \
  --yes

printf "${GREEN}MySQL Flexible Server deleted successfully.${NC}\n"
