# (C) Copyright IBM Corp. 2020  All Rights Reserved.
#
# This script implements/overrides the base functions defined in launch.sh
# This implementation is specific to this ibm-cfmr-prod operator

# ibm-cfmr operator specific variables
caseName="ibm-cfmr"
inventory="cfmrOperatorSetup"
caseCatalogName="cfmr-operator-catalog"
channelName="stable"
registry="${TARGET_REGISTRY:-ibmcloud}"
# - variables specific to catalog/operator installation
catalogNamespace="openshift-marketplace"
catalogDigest="@sha256:115a2dac05abf47f2b310921f9ae28eddd497fda79799377355fcbf2d5be5b48"

# ----- INSTALL ACTIONS -----


install_operator_group() {

    echo "check for any existing operator group in ${namespace} ..."

    if [[ $($kubernetesCLI get og -n "${namespace}" -o=go-template --template='{{len .items}}') -gt 0 ]]; then
        echo "found operator group"
        $kubernetesCLI get og -n "${namespace}" -o yaml
        return
    fi

    echo "no existing operator group found"

    echo "------------- Installing operator group for $namespace -------------"

    local opgrp_file="${casePath}/inventory/${inventory}/files/op-olm/operator_group.yaml"
    validate_file_exists "${opgrp_file}"

    sed <"${opgrp_file}" "s|REPLACE_NAMESPACE|${namespace}|g" | tee >($kubernetesCLI apply -n "${namespace}" -f -) | cat

    echo "done"
}

# Installs the catalog source and operator group
install_catalog() {

    validate_install_catalog


    echo "-------------Installing catalog source-------------"

    local catsrc_file="${casePath}/inventory/${inventory}/files/op-olm/catalog_source.yaml"

    # Verfy expected yaml files for install exit
    validate_file_exists "${catsrc_file}"

    # Apply yaml files manipulate variable input as required

    local catsrc_image_orig=$(grep "image:" "${catsrc_file}" | awk '{print$2}')

    # replace original registry with local registry
    local catsrc_image_mod="${registry}/$(echo "${catsrc_image_orig}" | sed -e "s/[^1]*\///")"

    # correct digest and apply catalog source
    sed <"${catsrc_file}" -e "s|${catsrc_image_orig}|${catsrc_image_mod}|g" | sed "s|:latest|${catalogDigest}|g" | tee >($kubernetesCLI apply -f -) | cat

    echo "done"
}

# Install utilizing default OLM method
install_operator() {
    # Verfiy arguments are valid
    validate_install_args

    install_operator_group

    echo "-------------Installing via OLM-------------"

    local subscription_file="${casePath}/inventory/${inventory}/files/op-olm/subscription.yaml"
    validate_file_exists "${subscription_file}"

    # check if catalog source is installed
    echo "checking if catalog source exists ..."
    if ! $kubernetesCLI get catsrc "${caseCatalogName}" -n "${catalogNamespace}"; then
        err_exit "expected catalog source '${caseCatalogName}' expected to be installed namespace '${catalogNamespace}'"
    fi

    # create subscription
    # fix namespace and channel before creating subscription
    sed <"${subscription_file}" -e "s|REPLACE_NAMESPACE|${namespace}|g" | sed "s|REPLACE_CHANNEL_NAME|$channelName|g" | tee >($kubernetesCLI apply -n "${namespace}" -f -) | cat
}

# Install utilizing default CLI method
install_operator_native() {
    # Verfiy arguments are valid
    validate_install_args

    # Proceed with install
    echo "-------------Installing native-------------"

    # Verify expected yaml files for install exist
    local op_cli_files="${casePath}/inventory/${inventory}/files/op-cli"
    local sa_file="${op_cli_files}/service_account.yaml"
    local role_file="${op_cli_files}/role.yaml"
    local role_binding_file="${op_cli_files}/role_binding.yaml"
    local operator_file="${op_cli_files}/operator.yaml"

    validate_file_exists "${sa_file}"
    validate_file_exists "${role_file}"
    validate_file_exists "${role_binding_file}"
    validate_file_exists "${operator_file}"

    # Apply yaml files manipulate variable input as required
    # - service account
    sed <"${sa_file}" "s|REPLACE_SECRET|$secret|g" | $kubernetesCLI apply -n "${namespace}" -f -
    # create crds
    for crdYaml in "${op_cli_files}"/*_crd.yaml; do
        $kubernetesCLI apply -n "${namespace}" -f "${crdYaml}"
    done
    # create role
    $kubernetesCLI apply -n "${namespace}" -f "${role_file}"
    # create role binding, after fixing namespace
    sed <"${role_binding_file}" "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI apply -n "${namespace}" -f -
    # create operator deployment
    $kubernetesCLI apply -n "${namespace}" -f "${operator_file}"
}

# ----- UNINSTALL ACTIONS -----


# deletes the catalog source and operator group
uninstall_catalog() {

    validate_install_catalog "uninstall"


    local catsrc_file="${casePath}"/inventory/"${inventory}"/files/op-olm/catalog_source.yaml

    echo "-------------Uninstalling catalog source-------------"
    $kubernetesCLI delete -f "${catsrc_file}" --ignore-not-found=true
}

# Uninstall operator installed via OLM
uninstall_operator() {
    echo "-------------Uninstalling operator-------------"
    # Find installed CSV
    csvName=$($kubernetesCLI get subscription "${caseCatalogName}"-subscription -o go-template --template '{{.status.installedCSV}}' -n "${namespace}" --ignore-not-found=true)
    # Remove the subscription
    $kubernetesCLI delete subscription "${caseCatalogName}-subscription" -n "${namespace}" --ignore-not-found=true
    # Remove the CSV which was generated by the subscription but does not get garbage collected
    [[ -n "${csvName}" ]] && { $kubernetesCLI delete clusterserviceversion "${csvName}" -n "${namespace}" --ignore-not-found=true; }

    # don't remove operator group, some other may have a dependency
    # $kubernetesCLI delete OperatorGroup "${caseCatalogName}-group" -n "${namespace}" --ignore-not-found=true

    # delete crds
    for crdYaml in "${casePath}"/inventory/"${inventory}"/files/op-cli/*_crd.yaml; do
        $kubernetesCLI delete -f "${crdYaml}" --ignore-not-found=true
    done
    # Delete catalog source
    # $kubernetesCLI delete CatalogSource "${caseCatalogName}" -n "${catalogNamespace}" --ignore-not-found=true
}

# Uninstall operator installed via CLI
uninstall_operator_native() {
    echo "-------------Uninstalling operator-------------"
    # Verify expected yaml files for uninstall and delete resources for each
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/service_account.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/service_account.yaml" --ignore-not-found=true; }
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/role.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/role.yaml" --ignore-not-found=true; }
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/role_binding.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/role_binding.yaml" --ignore-not-found=true; }
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/operator.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/operator.yaml" --ignore-not-found=true; }

    # - crds
    if [[ $deleteCRDs -eq 1 ]]; then
        echo "deleting crds"
        for crdYaml in "${casePath}"/inventory/"${inventory}"/files/op-cli/*_crd.yaml; do
            $kubernetesCLI delete -n "${namespace}" -f "${crdYaml}" --ignore-not-found=true
        done
    fi

}
