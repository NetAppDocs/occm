#!/bin/bash

createServiceProjectYAMLForBasicInstallation(){
cat <<EOF > scs-permissions.yaml
title: Snapcenter Service Script
stage: GA
description: Permissions for the service account associated with the Cloud Manager instance. Enables deployment for Snapcenter Service from Cloud Manager
includedPermissions:
- compute.firewalls.create
- compute.firewalls.delete
- compute.firewalls.get
- compute.firewalls.list
- compute.firewalls.update
- compute.globalOperations.get
- compute.instances.get
- compute.instances.list
- compute.instances.setMetadata
- compute.networks.updatePolicy
- compute.projects.get
- compute.projects.setCommonInstanceMetadata
- compute.zoneOperations.get
- compute.zones.list
- container.clusterRoleBindings.create
- container.clusterRoles.bind
- container.clusters.create
- container.clusters.delete
- container.clusters.get
- container.clusters.getCredentials
- container.clusters.list
- container.clusters.update
- container.operations.get
- iam.roles.get
- iam.serviceAccounts.actAs
- iam.serviceAccounts.get
- resourcemanager.projects.getIamPolicy
EOF
}

createServiceProjectYAMLForSharedVPCInstallation(){
cat <<EOF > scs-permissions-service-project.yaml
title: Snapcenter Service Shared VPC Service Project Script
stage: GA
description: Permissions for the service account associated with the Cloud Manager
  instance. Enables deployment for Snapcenter Service from Cloud Manager
includedPermissions:
- container.clusterRoleBindings.create
- container.clusterRoles.bind
- container.clusters.create
- container.clusters.delete
- container.clusters.update
- container.clusters.get
- container.clusters.getCredentials
- container.clusters.list
- container.operations.get
- compute.firewalls.create
- compute.firewalls.delete
- compute.firewalls.get
- compute.firewalls.list
- compute.firewalls.update
- compute.globalOperations.get
- compute.instances.get
- compute.networks.updatePolicy
- compute.instances.list
- compute.instances.setMetadata
- compute.projects.get
- compute.projects.setCommonInstanceMetadata
- compute.zoneOperations.get
- compute.zones.list
- iam.serviceAccounts.actAs
- iam.serviceAccounts.get
- iam.roles.get
- resourcemanager.projects.getIamPolicy
- compute.subnetworks.use
EOF
}

createHostProjectYAMLForSharedVPCInstallation(){
cat <<EOF > scs-permissions-host-project.yaml
title: Snapcenter Service Shared VPC Host Project Script
stage: GA
description: Permissions for the service account associated with the Cloud Manager instance for shared VPC. Enables deployment for Snapcenter Service from Cloud Manager
includedPermissions:
- compute.firewalls.create
- compute.firewalls.get
- compute.firewalls.list
- compute.firewalls.update
- compute.globalOperations.get
- compute.networks.updatePolicy
- compute.subnetworks.get
EOF
}

run_cmd() {
  echo "$@" >&2
  "$@"
  STATUS_CODE=$?
  echo
  return $STATUS_CODE
}

validate_basic_mode(){
    if [ -z ${project+x} ]; then echo "Project ID is unset. Use -p to set Project ID or -h for help."; exit 1; fi
    if [ -z ${account+x} ]; then echo "Account ID is unset. Use -a to set Account ID or -h for help."; exit 1; fi
}

validate_shared_vpc_mode(){
    validate_basic_mode
    if [ -z ${host_project+x} ]; then echo "Host Project ID is unset. Use -r to set Host Project ID or -h for help."; exit 1; fi
    if [ -z ${project_number+x} ]; then echo "Service Project Number is unset. Use -n to set Service Project Number or -h for help."; exit 1; fi
}



# Usage
show_help() {
cat << EOF
Usage: sh prerequisite.sh [-h] [-p <Project ID>] ...
Enable prerequisites to install SnapCenter Service in GCP
 
    -h                  display this help and exit
    -m Shared VPC Mode  Set this flag to enable prerequisites for Shared VPC.
    -p PROJECT          Service Project ID [PID].
    -a ACCOUNT          Service Account ID [SA]. E.g. "<SA>@<PID>.iam.gserviceaccount.com"
    -r HOST PROJECT     Host Project ID [HPID]. This is required for setting the pre requisites in the Service project of Shared VPC.  
    -n PROJECT NUMBER   Service Project Number[SPN]. This is required for setting the pre requisites in the Service project of Shared VPC.
EOF
}

# Initialize variables:
SERVICE_PROJECT_ROLE_NAME="SCLeastPermRole"
HOST_PROJECT_ROLE_NAME="SCLeastPermHostRole"

OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

while getopts hmp:a:r:n: opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        m)  mode=$((verbose+1))
            ;;
        p)  project=$OPTARG
            ;;
        a)  account=$OPTARG
            ;;
        r)  host_project=$OPTARG
            ;;
        n)  project_number=$OPTARG
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --

input() {
  while true; do
    read -p "$1 ([y]/n) " -r
    REPLY=${REPLY:-"y"}
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      return 1
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
      return 0
    fi
  done
}

cleanup(){
    echo "Cleaning up..."
    run_cmd rm $@
}

setUpGcloudAuthentication(){
    # Auto-completion
    input "You will be prompted to login via owner permissions so that we can set up your service account. Do you agree to continue?"
    proceed=$?

    if [ $proceed -eq 0 ]; then
        exit 1
    fi

    run_cmd gcloud auth login;
}

createOrUpdateRole(){
    role=$(gcloud iam roles describe $1 --project=$2 --format="value(name)")
    if [ $? -eq 0 ] && [ $role =  "projects/$2/roles/$1" ]; then
        run_cmd gcloud iam roles update $1 --project=$2 --file=$3
    else
        run_cmd gcloud iam roles create $1 --project=$2 --file=$3
    fi   

    return $?
}

updatePolicyBinding(){
    run_cmd gcloud projects add-iam-policy-binding $1 --member="serviceAccount:$2" --role=$3
    return $?
}

setUpBasicInstallation(){
    # Create the required yaml files
    createServiceProjectYAMLForBasicInstallation || { echo "Unable to create yaml file"; exit 1; }
    # Create resources
    createOrUpdateRole $SERVICE_PROJECT_ROLE_NAME $project scs-permissions.yaml || { echo "Unable to create role"; exit 1; }
    # Bind Resources
    ROLE="projects/$project/roles/$SERVICE_PROJECT_ROLE_NAME"
    updatePolicyBinding $project $account $ROLE || { echo "Unable to bind role to the service account in the service project [$project]"; exit 1; }

    cleanup scs-permissions.yaml  || { echo "Unable to remove files"; exit 1; }
}

setUpSharedVPCInstallation(){
    # Create the required yaml files
    createServiceProjectYAMLForSharedVPCInstallation || { echo "Unable to create yaml file"; exit 1; }
    createHostProjectYAMLForSharedVPCInstallation || { echo "Unable to create yaml file"; exit 1; }

    # Create resources
    createOrUpdateRole $SERVICE_PROJECT_ROLE_NAME $project scs-permissions-service-project.yaml || { echo "Unable to create role"; exit 1; }
    createOrUpdateRole $HOST_PROJECT_ROLE_NAME $host_project scs-permissions-host-project.yaml || { echo "Unable to create role"; exit 1; }

    # Bind Resources
    # 1. Service Project
    ROLE="projects/$project/roles/$SERVICE_PROJECT_ROLE_NAME"
    updatePolicyBinding $project $account $ROLE || { echo "Unable to bind role to the service account in the service project [$project]"; exit 1; }

    # 1. Host Project
    ROLE="projects/$host_project/roles/$HOST_PROJECT_ROLE_NAME"
    updatePolicyBinding $host_project $account $ROLE || { echo "Unable to bind role to the service account in the host project [$project]"; exit 1; }

    KUBERNETES_SERVICE_ROLE="roles/container.serviceAgent"
    GCP_SERVICE_ACCOUNT="service-$project_number@container-engine-robot.iam.gserviceaccount.com"
    updatePolicyBinding $host_project $GCP_SERVICE_ACCOUNT $KUBERNETES_SERVICE_ROLE || { echo "Unable to bind role to the service account in the host project [$project]"; exit 1; }

    cleanup scs-permissions-service-project.yaml scs-permissions-host-project.yaml || { echo "Unable to remove files"; exit 1; }

}

# Entrypoint
setUpGcloudAuthentication || exit 1;

if [ -z ${mode+x} ]
then 
validate_basic_mode;
setUpBasicInstallation;
echo "\nFollowing role has been created/updated in GCP:\n\t project/$project/roles/$SERVICE_PROJECT_ROLE_NAME";
else 
validate_shared_vpc_mode;
setUpSharedVPCInstallation;
echo "\nFollowing roles have been created/updated in GCP:\n\t project/$project/roles/$SERVICE_PROJECT_ROLE_NAME\n\t project/$host_project/roles/$HOST_PROJECT_ROLE_NAME";
fi

echo "\nSnapcenter Service pre-requisite creation for GCP project is successful.\nYou can deploy Snapcenter Service using the manual option in the UI, for the project [$project] and service account [$account].\n\nFor more details, visit https://docs.netapp.com/us-en/occm/media/SnapCenterService_betadoc.pdf"

exit 0