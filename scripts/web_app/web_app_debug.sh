#!/bin/bash

# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

# Configuration file path
CONFIG_FILE="$(dirname "$0")/web_app.config.sh"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    printf "${RED}Configuration file not found at $CONFIG_FILE${NC}\n"
    printf "Please run web_app_create.sh first to create the configuration.\n"
    exit 1
fi

# Source config file
source "$CONFIG_FILE"

# Verify required variables are set
if [ -z "$RG_NAME" ] || [ -z "$WEB_APP_NAME" ]; then
    printf "${RED}Error: Web app configuration is incomplete.${NC}\n"
    exit 1
fi

printf "${BLUE}Web App Name: ${NC}$WEB_APP_NAME\n"
printf "${BLUE}Resource Group: ${NC}$RG_NAME\n"
printf "${BLUE}Web App URL: ${NC}https://$WEB_APP_NAME.azurewebsites.net\n"
echo ""

printf "${GREEN}Tailing application logs...${NC}\n"
printf "${BLUE}Press Ctrl+C to stop${NC}\n"
echo ""

az webapp log tail --name $WEB_APP_NAME --resource-group $RG_NAME
