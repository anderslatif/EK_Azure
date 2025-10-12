#!/bin/bash

# Source terminal colors and password function
source "$(dirname "$0")/../misc/terminal_colors.sh"
source "$(dirname "$0")/../misc/read_password.sh"

# Configuration file path
CONFIG_FILE="$(dirname "$0")/mysql.config.sh"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    printf "${RED}Configuration file not found at $CONFIG_FILE${NC}\n"
    printf "Please run mysql_create.sh first to create the configuration.\n"
    exit 1
fi

echo "This is a script to set GitHub secrets for your repository based on the MySQL Flexible Server configuration."
echo "These secrets are used to connect the Azure Web App with the MySQL database."
printf "The secrets keys are ${GREEN}PROD_DATABASE_URL${NC}, ${GREEN}PROD_DATABASE_USERNAME${NC}, and ${GREEN}PROD_DATABASE_PASSWORD${NC}.\n"

# Source config file
source "$CONFIG_FILE"

# Verify required variables are set
if [ -z "$MYSQL_SERVER_NAME" ] || [ -z "$MYSQL_ADMIN_USER" ] || [ -z "$MYSQL_DB_NAME" ]; then
    printf "${RED}Error: MySQL configuration is incomplete.${NC}\n"
    exit 1
fi

echo ""
printf "${BLUE}MySQL Server: ${NC}$MYSQL_SERVER_NAME.mysql.database.azure.com\n"
printf "${BLUE}Database Name: ${NC}$MYSQL_DB_NAME\n"
echo ""

# Prompt for password
read_password "MySQL Admin Password: " MYSQL_ADMIN_PASSWORD

if [ -z "$MYSQL_ADMIN_PASSWORD" ]; then
    printf "${RED}Password cannot be empty.${NC}\n"
    exit 1
fi

# Construct the database URL
DATABASE_URL="$MYSQL_SERVER_NAME.mysql.database.azure.com:3306/$MYSQL_DB_NAME?useSSL=true"

# Display the secrets that will be set
printf "\n${BLUE}The following GitHub secrets will be set:${NC}\n"
echo "  PROD_DATABASE_URL: $DATABASE_URL"
echo "  PROD_DATABASE_USERNAME: $MYSQL_ADMIN_USER"
echo "  PROD_DATABASE_PASSWORD: ********"
echo ""

# Set GitHub secrets
printf "\n${GREEN}Setting GitHub secrets...${NC}\n"

printf "${BLUE}Setting PROD_DATABASE_URL...${NC}\n"
gh secret set PROD_DATABASE_URL --body "$DATABASE_URL"

printf "${BLUE}Setting PROD_DATABASE_USERNAME...${NC}\n"
gh secret set PROD_DATABASE_USERNAME --body "$MYSQL_ADMIN_USER"

printf "${BLUE}Setting PROD_DATABASE_PASSWORD...${NC}\n"
echo "$MYSQL_ADMIN_PASSWORD" | gh secret set PROD_DATABASE_PASSWORD

printf "\n${GREEN}GitHub secrets set successfully!${NC}\n"
printf "${BLUE}Your workflow can now use these secrets.${NC}\n"
