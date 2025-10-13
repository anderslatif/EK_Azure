#!/bin/bash

# Output only available region names (one per line)
# This script is meant to be called by other scripts

# Create a test resource group first
az group create --name "policy-test-rg" --location "uksouth" --output none 2>/dev/null

# Get all regions into an array
ALL_REGIONS=($(az account list-locations --query "[].name" --output tsv))
TOTAL_REGIONS=${#ALL_REGIONS[@]}
CURRENT=0

for region in "${ALL_REGIONS[@]}"; do
    # Strip carriage returns for Windows compatibility
    region="${region%$'\r'}"

    CURRENT=$((CURRENT + 1))
    # Print progress to stderr so it doesn't mix with region output
    printf "\rTesting regions: %d/%d" "$CURRENT" "$TOTAL_REGIONS" >&2

    storage_name="test$(date +%s)$RANDOM"

    if az storage account create \
        --name $storage_name \
        --resource-group "policy-test-rg" \
        --location $region \
        --sku Standard_LRS \
        --output none 2>/dev/null; then
        echo "$region"
        # Clean up
        az storage account delete --name $storage_name --resource-group "policy-test-rg" --yes --output none 2>/dev/null
    fi
done

# Clear progress line and print completion to stderr
printf "\rTesting complete: %d/%d regions tested\n" "$TOTAL_REGIONS" "$TOTAL_REGIONS" >&2

# Clean up resource group
az group delete --name "policy-test-rg" --yes --no-wait --output none 2>/dev/null