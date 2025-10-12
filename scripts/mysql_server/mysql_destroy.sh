#!/bin/bash

# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

# Configuration file path
CONFIG_FILE="$(dirname "$0")/mysql.config.sh"

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
echo ""

# Prompt for confirmation to delete MySQL server
read -p "Are you sure you want to delete the MySQL server? (y/yes): " CONFIRM
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

# Prompt for resource group deletion
echo ""
read -p "Do you also want to delete the resource group '$RG_NAME'? (y/yes): " CONFIRM_RG
if [[ "$CONFIRM_RG" =~ ^[Yy](es)?$ ]]; then
    printf "\n${GREEN}Deleting resource group...${NC}\n"
    az group delete --name $RG_NAME --yes --no-wait
    printf "${GREEN}Resource group deletion initiated.${NC}\n"
    printf "${BLUE}Note: Deletion happens asynchronously. Use 'az group list' to check status.${NC}\n"
else
    printf "${BLUE}Resource group '$RG_NAME' was not deleted.${NC}\n"
fi
