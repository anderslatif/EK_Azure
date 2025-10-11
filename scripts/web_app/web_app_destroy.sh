#!/bin/bash

# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

# Configuration file path
CONFIG_FILE="$(dirname "$0")/web_app.config.sh"

# Check if config file exists and source it
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    printf "${RED}Configuration file not found at $CONFIG_FILE${NC}\n"
    printf "Please run web_app.sh first to create the configuration.\n"
    exit 1
fi

# Verify required variables are set
if [ -z "$RG_NAME" ]; then
    printf "${RED}Error: Resource group name not found in configuration.${NC}\n"
    exit 1
fi

# Display what will be deleted
printf "${BLUE}This will delete the following Azure resources:${NC}\n"
echo "  - Resource Group: $RG_NAME"
echo "  - All resources within this resource group (Web App, App Service Plan, etc.)"
echo ""


# Delete resource group (this deletes all resources within it)
printf "\n${GREEN}Deleting resource group and all resources...${NC}\n"
az group delete --name $RG_NAME --yes --no-wait

printf "${GREEN}Resource group deletion initiated.${NC}\n"
printf "${BLUE}Note: Deletion happens asynchronously. Use 'az group list' to check status.${NC}\n"
