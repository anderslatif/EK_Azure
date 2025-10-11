#!/bin/bash

# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

# Configuration file paths
CONFIG_FILE="$(dirname "$0")/web_app.config.sh"
AVAILABLE_REGIONS_CONFIG="$(dirname "$0")/../available_regions/available_regions_config.sh"

# Check if variables are already defined, if not source or create config
if [ -z "$RG_NAME" ] || [ -z "$LOCATION" ] || [ -z "$WEB_APP_NAME" ] || [ -z "$APP_PLAN_NAME" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        # Config file exists, source it
        source "$CONFIG_FILE"
        # Also source available regions if exists
        [ -f "$AVAILABLE_REGIONS_CONFIG" ] && source "$AVAILABLE_REGIONS_CONFIG"
    else
        # Config file doesn't exist, show assumptions and prompt for confirmation
        printf "${BLUE}This script will create an Azure Web App with the following configuration:${NC}\n"
        echo "  - App Service Plan: F1 (Free tier)"
        echo "  - OS: Linux"
        echo "  - Runtime: Java 21"
        echo ""

        # Prompt for confirmation
        read -p "Do you want to proceed with these settings? (y/yes): " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy](es)?$ ]]; then
            printf "${RED}Setup cancelled.${NC}\n"
            exit 0
        fi

        # Prompt user and create config
        echo ""
        echo "Configuration file not found. Please provide the following details:"

        read -p "Resource Group Name [webapptest]: " RG_NAME
        RG_NAME=${RG_NAME:-webapptest}

        read -p "App Service Plan Name [webapp-plan]: " APP_PLAN_NAME
        APP_PLAN_NAME=${APP_PLAN_NAME:-webapp-plan}

        while true; do
            read -p "Web App Name (must be globally unique): " WEB_APP_NAME
            if [ -n "$WEB_APP_NAME" ]; then
                # Check if the web app name is already taken
                printf "${BLUE}Checking availability of '$WEB_APP_NAME'...${NC}\n"
                if az webapp list --query "[?defaultHostName=='$WEB_APP_NAME.azurewebsites.net'].name" --output tsv 2>/dev/null | grep -q .; then
                    printf "${RED}Web App name '$WEB_APP_NAME' is already taken. Please choose another name.${NC}\n"
                else
                    printf "${GREEN}Web App name '$WEB_APP_NAME' is available.${NC}\n"
                    break
                fi
            else
                printf "${RED}Web App Name cannot be empty.${NC}\n"
            fi
        done

        # Check if available regions config exists
        if [ -f "$AVAILABLE_REGIONS_CONFIG" ]; then
            # Load existing available regions
            source "$AVAILABLE_REGIONS_CONFIG"
        else
            # Get available regions (last prompt before deployment)
            printf "${BLUE}Fetching your available Azure regions...${NC} This will take several minutes but it will only be required the first time.\n"
            AVAILABLE_REGIONS_SCRIPT="$(dirname "$0")/../available_regions/available_regions.sh"
            AVAILABLE_REGIONS=()
            TEMP_REGIONS=$(bash "$AVAILABLE_REGIONS_SCRIPT")
            while IFS= read -r region; do
                [ -n "$region" ] && AVAILABLE_REGIONS+=("$region")
            done <<< "$TEMP_REGIONS"

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

        # Create config file
        {
            echo "# Web App Configuration"
            echo "RG_NAME=\"$RG_NAME\""
            echo "LOCATION=\"$LOCATION\""
            echo "WEB_APP_NAME=\"$WEB_APP_NAME\""
            echo "APP_PLAN_NAME=\"$APP_PLAN_NAME\""
        } > "$CONFIG_FILE"

        echo "Configuration saved to $CONFIG_FILE"
    fi
fi

# 1. Create Resource Group
printf "\n${GREEN}Creating resource group...${NC}\n"
az group create --name $RG_NAME --location $LOCATION

# 2. Create App Service Plan
printf "\n${GREEN}Creating App Service Plan...${NC}\n"
az appservice plan create \
  --name $APP_PLAN_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --sku F1 \
  --is-linux

# 3. Create Web App
printf "\n${GREEN}Creating Web App...${NC}\n"
az webapp create \
  --name $WEB_APP_NAME \
  --resource-group $RG_NAME \
  --plan $APP_PLAN_NAME \
  --runtime "JAVA:21-java21"

# 4. Display Web App URL
printf "\n${GREEN}Web App created successfully!${NC}\n"
printf "${BLUE}Web App URL: https://$WEB_APP_NAME.azurewebsites.net${NC}\n"
