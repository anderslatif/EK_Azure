# EK_Azure

Scripts and guides for Azure for Students accounts

---

## Guides

[Available Regions](./tutorials/available_regions/azure_available_regions.md)

Since changing to the EK domain there is a limitation of 5 available regions per account. It's diffferent for everyone. The guide above shows you how to find out which regions are available for your account.

[Azure Oddities](./tutorials/azure_oddities/azure_oddities.md)

A list of problems encountered in Azure and how to solve them.

[Azure Cost Management](./tutorials/azure_cost_management/azure_cost_managment.md)

How to keep track of spending and set up budgets and alerts.

---

## Scripts

### Prerequisites

1. Install `AZ CLI`:

https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&pivots=winget

Install with `winget` since the MSI installer is broken.

2. Log in with your browser to get the subscription id. In your terminal run:

```bash
$ az login
```

Make sure to select the correct subscription id when prompted.

3. If you are on **Windows** then make sure to run the scripts below on `Windows Subsystem for Linux`, `Git Bash` or the equivalent.

4. **Note**: a lot of output including "warnings" will be printed to the terminal. This is output from the Azure CLI and is normal.

---

### Available Regions

Find out which regions are available for your account:

```bash
$ ./available_regions/available_regions_standalone.sh
```

---

### VMs

#### Prerequisites

On Windows generate an ssh key pair with:

```bash
$ ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_rsa
```

#### Usage

Create a VM:

```bash
$ ./vm_scripts/vm_create.sh
```

Follow the prompts. It will take a few minutes to find what regions are available for your account but you will only need to do this once.

The VM configuration will be saved to `scripts/vm_scripts/vm.config.sh` while available regions will be saved to `scripts/available_regions/available_regions.config.sh`.

To destroy the VM:

```bash
$ ./vm_scripts/vm_destroy.sh
```

It will look at `vm.config.sh` to find the resource group to destroy.

