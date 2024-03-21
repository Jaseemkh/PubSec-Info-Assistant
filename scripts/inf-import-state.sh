# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

#!/bin/bash
set -e

figlet Import Terraform State

# escape special chars in a string
escape_string() {
    echo "$1" | sed 's/[][]/\\&/g'
}

# function to issue the import statement if the resource is not managed by Terraform
import_resource_if_needed() {
    local module_path=$1
    local resource_id=$2

    # endcode the $module_path
    module_path_escaped=$(escape_string "$module_path") 

    if [ ! -f "terraform.tfstate.d/$TF_VAR_environmentName/terraform.tfstate" ]; then
      # The RG is not managed by Terraform
      echo -e "\e[34mDeployment $TF_VAR_environmentName is not managed by Terraform. Importing $module_path\e[0m"
      terraform import "$module_path" "$resource_id"
    elif terraform state list | grep -q $module_path_escaped; then
      echo -e "\e[34mResource $module_path is already managed by Terraform\e[0m"
    else 
      # the module is not managed by terraform
      echo -e "\e[34mResource $module_path is not managed by Terraform. Importing $module_path\e[0m"
      terraform import "$module_path" "$resource_id"
    fi

}


get_secret() {
    local secret_name=$1
    local secret_id=$(az keyvault secret show --name $secret_name --vault-name $TF_VAR_keyVaultId --query id -o tsv)
    echo $secret_id
}


# Get the directory that this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/load-env.sh"
source "${DIR}/prepare-tf-variables.sh"
pushd "$DIR/../infra" > /dev/null
echo "Current Folder: $(basename "$(pwd)")"
echo "state file: terraform.tfstate.d/${TF_VAR_environmentName}/terraform.tfstate"

# Initialise Terraform with the correct path
${DIR}/terraform-init.sh "$DIR/../infra/"
echo

# Retrieve vars
for var in "${!TF_VAR_@}"; do
    echo "\$TF_VAR_${var#TF_VAR_} = ${!var}"
done

# Read randmom text suffix
file_path=".state/$TF_VAR_environmentName/random.txt"
if [ -f "$file_path" ]; then
    random_text=$(<"$file_path")
    random_text=$(echo "$random_text" | tr '[:upper:]' '[:lower:]')
    echo "random text suffix: $random_text"
else
    echo "Error: File '$TF_VAR_environmentName' not found."
fi


# ***********************************************************
# Import the existing resources into the Terraform state
# ***********************************************************

# Main
echo
figlet "Main"
resourceId="/subscriptions/$TF_VAR_subscriptionId/resourceGroups/$TF_VAR_resource_group_name"
import_resource_if_needed "azurerm_resource_group.rg" "$resourceId"
providers="/providers/Microsoft.Resources/deployments/pid-$random_text"
import_resource_if_needed "azurerm_resource_group_template_deployment.customer_attribution" "$resourceId$providers"


# Entra 
echo
figlet "Entra"
appName="infoasst-web-$random_text"
webAccessApp_name="infoasst_web_access_$random_text"

webAccessApp_id=$(az ad app list --filter "displayName eq '$webAccessApp_name'" --query "[].appId" --all | jq -r '.[0]')
import_resource_if_needed "module.entraObjects.azuread_application.aad_web_app" "/applications/$webAccessApp_id"





service_principal_id=$(az ad sp list --display-name "$appName" --query "[].id" | jq -r '.[0]')
echo "service_principal_id: " $service_principal_id
import_resource_if_needed "module.entraObjects.azuread_service_principal.aad_web_sp" $service_principal_id





# Keyvault id as it is used in multiple areas
TF_VAR_keyVaultId="infoasst-kv-$random_text"


# Storage 
echo
figlet "Storage"
TF_VAR_name="infoasststore$random_text"
echo "TF_VAR_name: " $TF_VAR_name
providers="/providers/Microsoft.Storage/storageAccounts/$TF_VAR_name"
import_resource_if_needed "module.storage.azurerm_storage_account.storage" "$resourceId$providers"

url="https://$TF_VAR_name.blob.core.windows.net/content"
import_resource_if_needed "module.storage.azurerm_storage_container.container[0]" "$url"
url="https://$TF_VAR_name.blob.core.windows.net/website"
import_resource_if_needed "module.storage.azurerm_storage_container.container[1]" "$url"
url="https://$TF_VAR_name.blob.core.windows.net/upload"
import_resource_if_needed "module.storage.azurerm_storage_container.container[2]" "$url"
url="https://$TF_VAR_name.blob.core.windows.net/function"
import_resource_if_needed "module.storage.azurerm_storage_container.container[3]" "$url"
url="https://$TF_VAR_name.blob.core.windows.net/logs"
import_resource_if_needed "module.storage.azurerm_storage_container.container[4]" "$url"
url="https://$TF_VAR_name..queue.core.windows.net/pdf-submit-queue"

import_resource_if_needed "module.storage.azurerm_storage_queue.queue[0]" "$url"
url="https://$TF_VAR_name..queue.core.windows.net/pdf-polling-queue"
import_resource_if_needed "module.storage.azurerm_storage_queue.queue[1]" "$url"
url="https://$TF_VAR_name..queue.core.windows.net/non-pdf-submit-queue"
import_resource_if_needed "module.storage.azurerm_storage_queue.queue[2]" "$url"
url="https://$TF_VAR_name..queue.core.windows.net/media-submit-queue"
import_resource_if_needed "module.storage.azurerm_storage_queue.queue[3]" "$url"
url="https://$TF_VAR_name..queue.core.windows.net/text-enrichment-queue"
import_resource_if_needed "module.storage.azurerm_storage_queue.queue[4]" "$url"
url="https://$TF_VAR_name..queue.core.windows.net/image-enrichment-queue"
import_resource_if_needed "module.storage.azurerm_storage_queue.queue[5]" "$url"
url="https://$TF_VAR_name..queue.core.windows.net/embeddings-queue"
import_resource_if_needed "module.storage.azurerm_storage_queue.queue[6]" "$url"

secret_id=$(get_secret "BLOB-CONNECTION-STRING")
import_resource_if_needed "module.storage.azurerm_key_vault_secret.storage_connection_string" "$secret_id"
secret_id=$(get_secret "AZURE-BLOB-STORAGE-KEY")
import_resource_if_needed "module.storage.azurerm_key_vault_secret.storage_connection_string" "$secret_id"


# Cosmos DB 
echo
figlet "Cosmos DB"
TF_VAR_name="infoasst-cosmos-$random_text"
echo "TF_VAR_name: " $TF_VAR_name
providers="/providers/Microsoft.DocumentDB/databaseAccounts/$TF_VAR_name"
import_resource_if_needed "module.cosmosdb.azurerm_cosmosdb_account.cosmosdb_account" "$resourceId$providers"
providers="/providers/Microsoft.DocumentDB/databaseAccounts/$TF_VAR_name/sqlDatabases/statusdb"
import_resource_if_needed "module.cosmosdb.azurerm_cosmosdb_sql_database.log_database" "$resourceId$providers"
providers="/providers/Microsoft.DocumentDB/databaseAccounts/$TF_VAR_name/sqlDatabases/statusdb/containers/statuscontainer"
import_resource_if_needed "module.cosmosdb.azurerm_cosmosdb_sql_container.log_container" "$resourceId$providers"
secret_id=$(get_secret "COSMOSDB-KEY")
import_resource_if_needed "module.storage.azurerm_key_vault_secret.storage_connection_string" "$secret_id"


# Search Service
echo
figlet "Search Service"
TF_VAR_name="infoasst-search-$random_text"
echo "TF_VAR_name: " $TF_VAR_name
providers="/providers/Microsoft.Search/searchServices/$TF_VAR_name"
import_resource_if_needed "module.searchServices.azurerm_search_service.search" "$resourceId$providers"
secret_id=$(get_secret "AZURE-SEARCH-SERVICE-KEY")
import_resource_if_needed "module.searchServices.azurerm_key_vault_secret.search_service_key" "$secret_id"
