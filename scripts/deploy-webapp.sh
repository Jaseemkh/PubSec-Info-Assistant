#!/bin/bash
set -e

figlet Deploy Webapp

# Get the directory that this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}"/../scripts/load-env.sh
source "${DIR}/environments/infrastructure.env"
BINARIES_OUTPUT_PATH="${DIR}/../artifacts/build/"

end=`date -u -d "3 years" '+%Y-%m-%dT%H:%MZ'`

cd $BINARIES_OUTPUT_PATH

# upload the zip file to blob storage
file=$(az storage blob upload --account-name $AZURE_BLOB_STORAGE_ACCOUNT --account-key $AZURE_BLOB_STORAGE_KEY --container-name website --name webapp.zip --file webapp.zip --overwrite)
# generate a SAS token for the zip file
sas=$(az storage blob generate-sas --account-name $AZURE_BLOB_STORAGE_ACCOUNT --account-key $AZURE_BLOB_STORAGE_KEY --container-name website --name webapp.zip --permissions r --expiry $end --output tsv)

# get the publishing profile for the webapp
#username=$(az webapp deployment list-publishing-profiles --resource-group infoasst-dayland --name infoasst-web-jg5so --query "[?publishMethod=='ZipDeploy'].userName" --output tsv)
#pwd=$(az webapp deployment list-publishing-profiles --resource-group infoasst-dayland --name infoasst-web-jg5so --query "[?publishMethod=='ZipDeploy'].userPWD" --output tsv)
#publishUrl=$(az webapp deployment list-publishing-profiles --resource-group infoasst-dayland --name infoasst-web-jg5so --query "[?publishMethod=='ZipDeploy'].publishUrl" --output tsv)

# deploy the zip file to the webapp
az webapp deploy --name $AZURE_WEBAPP_NAME --resource-group $RESOURCE_GROUP_NAME --type zip --src-path webapp.zip --async true --timeout 600000 --verbose

echo "Webapp deployed successfully"
