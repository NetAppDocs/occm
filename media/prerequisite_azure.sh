#!/bin/bash

validate() {
  if [ -z ${SubscriptionID+x} ]; then
    echo "No subscriptionID found, please specify connector's SubscriptionID. Use -s to set SubscriptionID or -h for help."
    exit 1
  fi
  if [ -z ${ConnectorName+x} ]; then
    echo "No Connector name found, please specify Connector Name. Use -c to set ConnectorName or -h for help."
    exit 1
  fi
  if [ -z ${ResourceGroup+x} ]; then
    echo "No resource group found, please specify connector's ResourceGroup Name. Use -g to set ResourceGroup or -h for help."
    exit 1
  fi
}

# Usage
show_help() {
  cat <<EOF
Usage: sh prerequisite_azure.sh [-h] -s <SubscriptionID> -g <ResourceGroup> -c <ConnectorName>...
Enable prerequisites to install SnapCenter Service in AZURE

    -h                  display this help and exit
    -s SubscriptionID   connector's subscriptionID.
    -g ResourceGroup    connector's ResourceGroup Name.
    -c ConnectorName    connector VM Name.
EOF
}

createUserMSI() {
  #prepare msi name
  userMSIName="SnapCenter-MSI-"${ConnectorName}

  #echo "user assigned managed identity name is: " $userMSIName
  echo "user assigned managed identity name is: " "$userMSIName"

  #set az account
  az account set --subscription "${SubscriptionID}"

  #Create user managed identity under the given service connector's resource group
  userMSIPrincipleID=$(az identity create -g "$ResourceGroup" -n "$userMSIName" --query 'principalId' -o tsv)

  if [ -z "$userMSIPrincipleID" ]; then
    echo "Failed to create the user managed identity."
    exit 1
  fi

  echo "user managed identity created, principalId: " "${userMSIPrincipleID}"

}

createManagedClusterRole() {
  #prepare managed cluster role name
  strhypen="-"
  ManagedClusterRoleName="SnapCenter-AKS-Cluster-Admin-"${ResourceGroup}${strhypen}${ConnectorName}

  #prepare service connector rg scope
  rgScope="/subscriptions/$SubscriptionID/resourceGroups/"${ResourceGroup}
  echo "Service connector's resource group scope: " "$rgScope"

  # check if role already exists
  echo "Started creating SnapCenter AKS cluster management role"
  sleep 30
  ManagedClusterRoleDefID=$(az role definition list --custom-role-only true -n "$ManagedClusterRoleName" --scope "$rgScope" --subscription "$SubscriptionID" --query [0].id -o tsv)

  if [ ! -z "$ManagedClusterRoleDefID" ]; then
    echo "custom role '$ManagedClusterRoleName' already exists, RoleDefinitionID:" "$ManagedClusterRoleDefID"
    return
  fi

  #create custom role snapcenter managed cluster at rg scope
  ManagedClusterRoleDefID=$(az role definition create --role-definition '{
  "Name":"'"$ManagedClusterRoleName"'",
  "IsCustom": true,
  "Description": "SnapCenter AKS cluster management role",
  "Actions": [
   "Microsoft.Resources/subscriptions/resourceGroups/read",
   "Microsoft.ContainerService/managedClusters/write",
   "Microsoft.ContainerService/managedClusters/read",
   "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",
   "Microsoft.ManagedIdentity/userAssignedIdentities/read",
   "Microsoft.ContainerService/managedClusters/delete",
   "Microsoft.Compute/virtualMachines/read",
   "Microsoft.Network/networkInterfaces/read",
   "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action"
  ],
  "NotActions": [

  ],
  "AssignableScopes": [
    "'"$rgScope"'"
  ]
}' --query 'id' -o tsv)

  if [ -z "$ManagedClusterRoleDefID" ]; then
    echo "Failed to create the custom role: '$ManagedClusterRoleName'"
    exit 1
  fi

  echo "custom role '$ManagedClusterRoleName' created, RoleDefinitionID:" "$ManagedClusterRoleDefID"

}

createNetworkManagementRole() {
  #prepare managed cluster role name
  strhypen="-"
  NetworkManagementRoleName="SnapCenter-Network-Management-"${ResourceGroup}${strhypen}${ConnectorName}

  #Get service connector's subnet scope
  nic=$(az vm show -n "$ConnectorName" -g "$ResourceGroup" --query 'networkProfile.networkInterfaces[0].id' -o tsv)

  if [ -z "$nic" ]; then
    echo "Failed to get the network details"
    exit 1
  fi

  echo "NIC:""$nic"

  subnetScope=$(az vm nic show -g "$ResourceGroup" --vm-name "$ConnectorName" --nic "$nic" --query 'ipConfigurations[0].subnet.id' -o tsv)

  #get network subscriptionID
  networkSubscriptionID=$(echo "$subnetScope" | cut -d'/' -f 3)

  echo "networkSubscriptionID: " "$networkSubscriptionID"

  #get network resourcegroup
  networkResourceGroup=$(echo "$subnetScope" | cut -d'/' -f 5)
  echo "networkResourceGroup: " "$networkResourceGroup"

  #get network vnet name
  virtualNetworkName=$(echo "$subnetScope" | cut -d'/' -f 9)
  echo "virtualNetworkName: " "$virtualNetworkName"

  #prepare vnet scope
  vnetScope="/subscriptions/$networkSubscriptionID/resourceGroups/$networkResourceGroup/providers/Microsoft.Network/virtualNetworks/$virtualNetworkName"
  echo "vnetScope: " "$vnetScope"

  # check if role already exists
  echo "Started creating SnapCenter AKS network management role"
  sleep 30
  NetworkRoleDefID=$(az role definition list --custom-role-only true -n "$NetworkManagementRoleName" --scope $vnetScope --subscription "$networkSubscriptionID" --query [0].id -o tsv)

  if [ ! -z "$NetworkRoleDefID" ]; then
    echo "custom role '$NetworkManagementRoleName' already exists, RoleDefinitionID:" "$NetworkRoleDefID"
    return
  fi

  #create snapcenter network management custom role at occm vnet scope
  NetworkRoleDefID=$(az role definition create --role-definition '{
  "Name": "'"$NetworkManagementRoleName"'",
  "IsCustom": true,
  "Description": "SnapCenter AKS network management role",
  "Actions": [
   "Microsoft.Network/virtualNetworks/subnets/read",
   "Microsoft.Authorization/roleAssignments/read",
   "Microsoft.Network/virtualNetworks/subnets/join/action",
   "Microsoft.Network/virtualNetworks/read"
  ],
  "NotActions": [
  ],
  "AssignableScopes": [
    "'"$vnetScope"'"
  ]
}' --query 'id' -o tsv)

  if [ -z "$NetworkRoleDefID" ]; then
    echo "Failed to create the custom role: '$NetworkManagementRoleName'"
    exit 1
  fi

  echo "custom role '$NetworkManagementRoleName' created, RoleDefinitionID:" "$NetworkRoleDefID"
}

roleAssignments() {
  #sleep for few seconds, because sometimes user msi wont be created, adding sleep for 45 seconds
  echo "adding sleep for 45 seconds, to ensure MSI is already created before role assignment, even after that if role assignment fails then re-execute the script."
  sleep 45

  #Assign custom role to user msi
  managedClusterRoleAssignmentID=$(az role assignment create --assignee "$userMSIPrincipleID" --role "$ManagedClusterRoleName" --resource-group "$ResourceGroup" --query 'id' -o tsv)

  if [ -z "$managedClusterRoleAssignmentID" ]; then
    echo "Failed to assign the role: '$NetworkManagementRoleName' to user managed identity."
    exit 1
  fi

  echo "Successfully assigned the role '$ManagedClusterRoleName' to user managed identity and and the Role AssignmentId is '$managedClusterRoleAssignmentID'"

  #sleep for few seconds, because azure sometimes takes time to reflect the permissions
  echo "adding sleep for 45 seconds, to make sure permissions are reflected"
  sleep 45

  #Assign Network Contributor role to user msi
  networkRoleAssignmentID=$(az role assignment create --assignee "$userMSIPrincipleID" --role "$NetworkManagementRoleName" --scope "$vnetScope" --query 'id' -o tsv)

  if [ -z "$networkRoleAssignmentID" ]; then
    echo "Failed to assign the role: '$NetworkManagementRoleName' to user managed identity."
    exit 1
  fi

  echo "Successfully assigned the role '$NetworkManagementRoleName' to user managed identity and the Role AssignmentId is '$networkRoleAssignmentID'"
}

assignUserMSI() {
  #Assign user msi to service connector
  userAssignedIdentities=$(az vm identity assign -g "$ResourceGroup" -n "$ConnectorName" --identities "$userMSIName")

  if [ -z "$userAssignedIdentities" ]; then
    echo "Failed to assign user managed identity to service connector. '$userAssignedIdentities'"
    exit 1
  fi

  bold=$(tput bold)
  normal=$(tput sgr0)

  echo "User assigned managed identity ${bold}'$userMSIName'${normal} successfully created and assigned to connector."
}

#Entrypoint
OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

while getopts h:s:g:c: opt; do
  case $opt in
  h)
    show_help
    exit 0
    ;;
  s)
    SubscriptionID=$OPTARG
    ;;
  g)
    ResourceGroup=$OPTARG
    ;;
  c)
    ConnectorName=$OPTARG
    ;;
  *)
    show_help >&2
    exit 1
    ;;
  esac
done
shift "$((OPTIND - 1))" # Discard the options and sentinel --

validate
echo "The script takes around 4 to 5 minutes as role creation and assignments take time to reflect."
createUserMSI
createManagedClusterRole
createNetworkManagementRole
roleAssignments
assignUserMSI
