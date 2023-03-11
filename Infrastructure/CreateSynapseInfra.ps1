$subscriptionName = 'LefeWareSolutions-POC'
$location = "centralus"
$locationShort = "cus"
$environmentShort = "stg"
$orgNameShort = "lws" 
$appName = "dfcicd"
$resourceGroupName = "$($orgNameShort)-$($locationShort)-$($environmentShort)-$($appName)-rg"

# Connect to Azure and Set Current Subscription Context
Connect-AzAccount
$context = Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext $context

# Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create Src and Dest Storage accounts
$srcStorageAccountName = "$($orgNameShort)$($locationShort)$($environmentShort)$($appName)stg1"
$destStorageAccountName = "$($orgNameShort)$($locationShort)$($environmentShort)$($appName)stg2"
New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $srcStorageAccountName -Location $location -SkuName Standard_LRS -Kind StorageV2 -AccessTier Hot
New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $destStorageAccountName -Location $location -SkuName Standard_LRS -Kind StorageV2 -AccessTier Hot

#Upload SampleCSVFile1.csv to Source Storage Account
$srcStorageAccountContext = New-AzStorageContext -StorageAccountName $srcStorageAccountName -StorageAccountKey (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $srcStorageAccountName)[0].Value
New-AzStorageContainer -Name "data" -Context $srcStorageAccountContext
Set-AzStorageBlobContent -File "SampleCSVFile1.csv" -Container "data" -Blob "SampleCSVFile1.csv" -Context $srcStorageAccountContext

#Create KeyVault
$keyVaultName = "$($orgNameShort)$($locationShort)$($environmentShort)$($appName)keyvault"
New-AzKeyVault -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -Location $location -Sku Standard

#Get storage account full connection strings and store them in keyvault
$srcStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $srcStorageAccountName)[0].Value
$destStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $destStorageAccountName)[0].Value
$srcStorageAccountConnectionString = "DefaultEndpointsProtocol=https;AccountName=$srcStorageAccountName;AccountKey=$srcStorageAccountKey;EndpointSuffix=core.windows.net"
$destStorageAccountConnectionString = "DefaultEndpointsProtocol=https;AccountName=$destStorageAccountName;AccountKey=$destStorageAccountKey;EndpointSuffix=core.windows.net"
$srcStorageAccountConnectionString = ConvertTo-SecureString -String $srcStorageAccountConnectionString -AsPlainText -Force
$destStorageAccountConnectionString = ConvertTo-SecureString -String $destStorageAccountConnectionString -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "srcStorageAccountConnectionString" -SecretValue $srcStorageAccountConnectionString
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "destStorageAccountConnectionString" -SecretValue $destStorageAccountConnectionString

# Create Azure Synapse Workspace
$synapseName = "$($orgNameShort)-$($locationShort)-$($environmentShort)-$($appName)-synapse"
$dataLakeName = "$($orgNameShort)$($locationShort)$($environmentShort)$($appName)dl"
$defaultDataLakeStorageFilesystem = "ContosoFileSystem"
$password = ConvertTo-SecureString "Password123!" -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ("ContosoUser", $password)
New-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseName -Location $location -DefaultDataLakeStorageAccountName $dataLakeName -DefaultDataLakeStorageFilesystem  $defaultDataLakeStorageFilesystem -SqlAdministratorLoginCredential  $creds


#Get Azure Synapse Principal ID
$principalId = (Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseName).Identity.PrincipalId
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $principalId -PermissionsToSecrets get
