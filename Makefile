AZ_LOCATION       := eastus
AZ_PIPELINE       := AzureFunctionExample
AZ_RESOURCE_GROUP := AzureFunctionExample
REPO              := https://github.com/andreif-funnel/AzureFunctionExample


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
	az pipelines create --name $(AZ_PIPELINE) --yml-path azure-pipelines.yml --repository $(REPO) || \
	az pipelines update --name $(AZ_PIPELINE) --yml-path azure-pipelines.yml


.PHONY: resources
resources:
	az group create \
	  --name $(AZ_RESOURCE_GROUP) \
	  --location $(AZ_LOCATION) \
	  --verbose
	az group deployment create \
	  --resource-group $(AZ_RESOURCE_GROUP) \
	  --template-file Resources.json \
	  --mode Complete \
	  --debug \
	  --verbose
