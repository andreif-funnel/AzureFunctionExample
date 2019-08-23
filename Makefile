AZ_LOCATION       := eastus
AZ_PIPELINE       := AzureFunctionExample
AZ_RESOURCE_GROUP := AzureFunctionExample
REPO              := https://github.com/andreif-funnel/AzureFunctionExample
AZ_APP            := $(AZ_RESOURCE_GROUP)Functions


.PHONY: clean
clean:
	pipenv --rm
	rm -r Functions/.python_packages
	rm -r Functions/requirements.txt


.PHONY: pipeline
pipeline:
	@test -n "$(AZ_ORGANIZATION)"   || (echo "AZ_ORGANIZATION" ; exit 1)
	@test -n "$(AZ_PROJECT)"        || (echo "AZ_PROJECT"      ; exit 1)
	@test -n "$(AZ_SUBSCRIPTION)"   || (echo "AZ_SUBSCRIPTION" ; exit 1)

	az extension add --name azure-devops
	az devops configure --defaults organization=https://dev.azure.com/$(AZ_ORGANIZATION)/ project=$(AZ_PROJECT)

	az pipelines variable create --name azureSubscription --value "$(AZ_SUBSCRIPTION)" --pipeline-name $(AZ_PIPELINE) || \
	az pipelines variable update --name azureSubscription --value "$(AZ_SUBSCRIPTION)" --pipeline-name $(AZ_PIPELINE)

	az pipelines variable create --name resourceGroupName --value $(AZ_RESOURCE_GROUP) --pipeline-name $(AZ_PIPELINE) || \
	az pipelines variable update --name resourceGroupName --value $(AZ_RESOURCE_GROUP) --pipeline-name $(AZ_PIPELINE)

	az pipelines variable create --name location          --value $(AZ_LOCATION)       --pipeline-name $(AZ_PIPELINE) || \
	az pipelines variable update --name location          --value $(AZ_LOCATION)       --pipeline-name $(AZ_PIPELINE)

	az pipelines variable create --name system.debug      --value true                 --pipeline-name $(AZ_PIPELINE) || \
	az pipelines variable update --name system.debug      --value true                 --pipeline-name $(AZ_PIPELINE)

	az pipelines create --name $(AZ_PIPELINE) --yml-path azure-pipelines.yml --repository $(REPO) || \
	az pipelines update --name $(AZ_PIPELINE) --yml-path azure-pipelines.yml


.PHONY: pipeline_secrets
pipeline_secrets:
	@test -n "$(AWS_S3_BUCKET)"         || (echo "AWS_S3_BUCKET"         ; exit 1)
	@test -n "$(AWS_ACCESS_KEY_ID)"     || (echo "AWS_ACCESS_KEY_ID"     ; exit 1)
	@test -n "$(AWS_SECRET_ACCESS_KEY)" || (echo "AWS_SECRET_ACCESS_KEY" ; exit 1)

	az pipelines variable create --name AWS_S3_BUCKET         --value $(AWS_S3_BUCKET)         --pipeline-name $(AZ_PIPELINE) || \
	az pipelines variable update --name AWS_S3_BUCKET         --value $(AWS_S3_BUCKET)         --pipeline-name $(AZ_PIPELINE)

	az pipelines variable create --name AWS_ACCESS_KEY_ID     --value $(AWS_ACCESS_KEY_ID)     --pipeline-name $(AZ_PIPELINE) --secret true || \
	az pipelines variable update --name AWS_ACCESS_KEY_ID     --value $(AWS_ACCESS_KEY_ID)     --pipeline-name $(AZ_PIPELINE) --secret true

	az pipelines variable create --name AWS_SECRET_ACCESS_KEY --value $(AWS_SECRET_ACCESS_KEY) --pipeline-name $(AZ_PIPELINE) --secret true || \
	az pipelines variable update --name AWS_SECRET_ACCESS_KEY --value $(AWS_SECRET_ACCESS_KEY) --pipeline-name $(AZ_PIPELINE) --secret true


.PHONY: resources
resources:
	az group create \
	  --name $(AZ_RESOURCE_GROUP) \
	  --location $(AZ_LOCATION) \
	  --verbose
	az group deployment create \
	  --resource-group $(AZ_RESOURCE_GROUP) \
	  --template-file Resources.json \
	  --debug \
	  --verbose 2>&1 | tee az-group-deployment-create.log


.PHONY: function
function:
	pipenv lock -r > Functions/requirements.txt
	cd Functions && func azure functionapp publish $(AZ_APP) --build-native-deps


.PHONY: list_settings
list_settings:
	az webapp config appsettings list --name $(AZ_APP) --resource-group $(AZ_RESOURCE_GROUP)


.PHONY: set_secrets
set_secrets:
	az webapp config appsettings set -g $(AZ_RESOURCE_GROUP) -n $(AZ_APP) --settings \
		AWS_S3_BUCKET=$(AWS_S3_BUCKET) \
		AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
		AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY)


.PHONY: create_key_vault
create_key_vault:
	az group create --name $resourceGroupName --location $location
	az keyvault create \
	  --name $(AZ_RESOURCE_GROUP) \
	  --resource-group $(AZ_RESOURCE_GROUP) \
	  --location $(AZ_LOCATION) \
	  --enabled-for-template-deployment true
	az keyvault secret set --vault-name $(AZ_RESOURCE_GROUP) --name "AWS_S3_BUCKET"         --value "$(AWS_S3_BUCKET)"
	az keyvault secret set --vault-name $(AZ_RESOURCE_GROUP) --name "AWS_ACCESS_KEY_ID"     --value "$(AWS_ACCESS_KEY_ID)"
	az keyvault secret set --vault-name $(AZ_RESOURCE_GROUP) --name "AWS_SECRET_ACCESS_KEY" --value "$(AWS_SECRET_ACCESS_KEY)"


.PHONY: list_deployments
list_deployments:
	az group deployment list --resource-group $(AZ_RESOURCE_GROUP) | \
	jq '[.[].properties | {when:.timestamp, state:.provisioningState, \
	 mode:.mode, duration:.duration, corr:.correlationId}]'
