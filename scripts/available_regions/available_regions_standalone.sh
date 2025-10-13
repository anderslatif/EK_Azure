#!/bin/bash

# Source terminal colors
source "$(dirname "$0")/../misc/terminal_colors.sh"

echo -e "${BLUE}Testing regions with storage account creation...${NC}"
echo ""

# Create a test resource group first
az group create --name "policy-test-rg" --location "uksouth" --output none 2>/dev/null

for region in $(az account list-locations --query "[].name" --output tsv); do
    # Strip carriage returns for Windows compatibility
    region="${region%$'\r'}"

    printf "${YELLOW}%-30s${NC} " "$region..."

    storage_name="test$(date +%s)$RANDOM"

    if az storage account create \
        --name $storage_name \
        --resource-group "policy-test-rg" \
        --location $region \
        --sku Standard_LRS \
        --output none 2>/dev/null; then
        printf "${GREEN}✅ AVAILABLE${NC}\n"
        # Clean up
        az storage account delete --name $storage_name --resource-group "policy-test-rg" --yes --output none 2>/dev/null
    else
        printf "${RED}❌ BLOCKED${NC}\n"
    fi
done

# Clean up resource group
az group delete --name "policy-test-rg" --yes --no-wait --output none 2>/dev/null
