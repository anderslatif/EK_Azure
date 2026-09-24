# Create an AlmaLinux VM using `az`


0. Accept the AlmaLinux license agreement by running the following command (only needs to be done once):

```bash
az vm image terms accept --urn almalinux:almalinux-x86_64:9-gen2:latest
```

1. Create a resource group (Make sure to replace `<resource_group_name>` with your desired resource group name and `<available_region>` with your preferred Azure region):

```bash
az group create --name <resource_group_name> --location <available_region>
```

2. Create the VM. (Replace `<vm_name>` with your desired VM name and update with the values from the previous step):

```bash
az vm create \
  --resource-group <resource_group_name> \
  --name <vm_name> \
  --image almalinux:almalinux-x86_64:9-gen2:latest \
  --size Standard_B2s \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-sku Standard \
  --output table
```

