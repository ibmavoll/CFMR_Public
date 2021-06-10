#!/bin/bash
PREFIX=dev

#set -e

usage_and_exit() {
  cat <<EOF
Usage: pcfusage <PREFIX> <CMD>[ALL|APPS|SRVS] <CSV>[yes/NO]
  
  where: CMD=ALL  - all foundation information
         CMD=APPS - Apps in CSV format - REQUIRED THE OUTPUT OF 'ALL' RUN - DEPRECATED
         CMD=SRVS - service bindings - REQUIRED THE OUTPUT OF 'ALL' RUN - DEPRECATED
Examples:
  pcfusage dev - defaults to ALL and NO 
  pcfusage dev apps - creates apps csv file
  pcfusage dev srvs - creates a file with the app bindings guids
EOF
  exit 1
}

###############################################
# CREATE_ARRAY - Create an array of spaces in the system org we used to filter those apps
###############################################
create_array() {

local TRACE_OFF=${1:-FALSE}

  system_org_guid=`jq ".[].orgs[]? | select(.name == \"$1\") | .org_guid" ${PREFIX}_foundation.json`
  if [ -z "$system_org_guid" ]; then
    if [ "$TRACE_OFF" == "FALSE" ]; then
      printf "\nOrg $1 not found. Skipping...\n"
    fi
    return
  fi

  if [ "$#" -gt 1 ]; then
    arr=$arr","
  fi

  if [ "$TRACE_OFF" == "FALSE" ]; then
    printf "\n$1 Org GUID is $system_org_guid \n"
  fi

  spaces=$(cat ${PREFIX}_foundation.json | jq ".[].spaces[]? | select(.org == $system_org_guid) | .space_guid")
  if [ "$TRACE_OFF" == "FALSE" ]; then
    printf "\nSpaces in $1 org are: \n'$spaces' \n"
  fi

  c=1
  while read -r line; do
      #echo "... $line ..."
      if [ "$c" -gt "1" ]; then
         arr=$arr","
      fi
      arr=${arr}${line}
      c=$((c + 1))
  done <<< "$spaces"

}

################################################
# Creates CSV file with non system applications
################################################
create_csv() {
printf "\nNow I'm generating CSV file with only non system apps...\n"

non_system_app

jq -r ".apps[] | [.name, .memory, .state, .instances, .buildpack, .space, .updated] | @csv" --compact-output ${PREFIX}_final_apps.json > ${PREFIX}_apps.csv
rm ${PREFIX}_final_apps.json

printf "\nCreated '${PREFIX}_apps.csv'!"
}

################################################
# NON_SYSTEM_APPS - Creates a list of non-system apps
################################################
non_system_app() {

if [ ! -f "${PREFIX}_foundation.json" ]; then
    printf "\nERROR: Foundation file '${PREFIX}_foundation.json' doesn't exist.\n"
    printf "Make sure you ran with CMD=ALL (default), first"
    exit 1
fi

local TRACE_OFF=${1:-FALSE}

if [ "$TRACE_OFF" == "FALSE" ]; then
  printf "\ncreating ${PREFIX}_final_apps.json file...\n"
fi

arr="["
  create_array "system"
  create_array "p-dataflow" ","
  create_array "p-spring-cloud-services" ","
arr=$arr"]"
if [ "$TRACE_OFF" == "FALSE" ]; then
  printf "\nSpaces from 'system' Orgs: $arr \n"
fi

# Filter out all app in system org spaces
apps=$(cat ${PREFIX}_foundation.json | jq -r "$arr as \$system_spaces | {apps: [.[].apps[]? | select(.space as \$in | \$system_spaces | index(\$in) | not)]}")
echo $apps > ${PREFIX}_final_apps.json  
}

################################################
# READ_PAGES - Read CF API pages
# Parms: URL, FILE_NAME and JQ FILTER
################################################
read_pages() {

local API_URL=$1
local NAME=$2
local FILTER=$3
local TRACE_OFF=${4:-FALSE}

if [ "$TRACE_OFF" == "FALSE" ]; then
  echo "Reading pages... "
fi
# echo "$1 is the URL to call"
# echo "$2 is the file prefix"
# echo "$3 is the ja filter"

local next_url="${1}"
if [ "$TRACE_OFF" == "FALSE" ]; then
  echo $next_url
fi

local c=1

while [[ "${next_url}" != "null" ]]; do
  file_json=$(cf curl ${next_url}) 
  next_url=$(echo $file_json | jq -r -c ".next_url")
  
  if [ "$NAME" == "info" ]; then
    file=$(echo $file_json | jq "[. | $FILTER]")
  else
    file=$(echo $file_json | jq "[.resources[] | $FILTER]")
  fi  
  echo $file > ${NAME}_page_${c}.json
  c=$((c + 1))
done
files=$(jq -s "{${NAME}: [.[][]]}" ${NAME}_page_*.json)
echo $files > ${PREFIX}_${NAME}.json
rm ${NAME}_page_*.json 
if [ "$TRACE_OFF" == "FALSE" ]; then
  echo "Done. Created file ${PREFIX}_${NAME}.json"
fi
}

###############################################
# CREATE_USERS - List all users into PREFIX_users.json
###############################################
create_users() {
  printf "\ncreating ${PREFIX}_users.json file...\n"
  read_pages "/v2/users?results-per-page=100" "users" "select (.entity.username | test(\"system_*|smoke_tests|admin|MySQL*|push_apps*\"; \"i\") | not)? | {username: .entity.username}"
}

###############################################
# CREATE_INFO - Foundation Info
###############################################
create_info() {
  printf "\ncreating ${PREFIX}_info.json file...\n"
  read_pages "/v2/info" "info" "{name: .name, build: .build, version: .version, description: .description, api_version: .api_version, osbapi_version: .osbapi_version }"
}

###############################################
# CREATE_ORGS - List all organizations into PREFIX_orgs.json
###############################################
create_orgs() {
  printf "\ncreating ${PREFIX}_orgs.json file...\n"
  read_pages "/v2/organizations?results-per-page=100" "orgs" "{org_guid: .metadata.guid, name: .entity.name }"
}

###############################################
# CREATE_SPACES - List all spaces into PREFIX_spaces.json
###############################################
create_spaces() {
  printf "\ncreating ${PREFIX}_spaces.json file...\n"
  read_pages "/v2/spaces?results-per-page=100" "spaces" "{name: .entity.name, space_guid: .metadata.guid, org: .entity.organization_guid }"
}

###############################################
# CREATE_SERVICE - List all service brokers
###############################################
create_services() {
  printf "\ncreating ${PREFIX}_services.json file...\n"
  read_pages "/v2/services?results-per-page=100" "services" "{service_guid: .metadata.guid, label: .entity.label, service_broker_guid: .entity.service_broker_guid }"
}

###############################################
# CREATE_SERVICE_PLANS - List all service brokers plans
###############################################
create_service_plans() {
  printf "\ncreating ${PREFIX}_service_plans.json file...\n"
  read_pages "/v2/service_plans?results-per-page=100" "service_plans" "{service_plan_guid: .metadata.guid, service_guid: .entity.service_guid, name: .entity.name, description: .entity.description, extra: .entity.extra }"
}

###############################################
# CREATE_SERVICE_INSTANCES - List all service instances
###############################################
create_service_instances() {
  printf "\ncreating ${PREFIX}_service_instances.json file...\n"
  read_pages "/v2/service_instances?results-per-page=100" "service_instances" "{name: .entity.name, service_instance_guid: .metadata.guid, service_guid: .entity.service_guid, space_guid: .entity.space_guid, service_plan_guid: .entity.service_plan_guid, type: .entity.type, tags: (.entity.tags | sort | join(\"|\") | if .==\"\" then \"null\" else . end)}"
}

###############################################
# CREATE_USER_PROVIDED_SERVICE_INSTANCES - List all user provided service instances
###############################################
create_user_provided_service_instances() {
  printf "\ncreating ${PREFIX}_user_provided_service_instances.json file...\n"
  read_pages "/v2/user_provided_service_instances?results-per-page=100" "user_provided_service_instances" "{name: .entity.name, service_instance_guid: .metadata.guid, space_guid: .entity.space_guid }"
}

###############################################
# CREATE_SERVICE_BINDINGS - List all service bindings
###############################################
create_service_bindings() {
  printf "\ncreating ${PREFIX}_service_bindings.json file...\n"
  read_pages "/v2/service_bindings?results-per-page=100" "service_bindings" "{guid: .metadata.guid , app_guid: .entity.app_guid , service_instance_guid: .entity.service_instance_guid}"
}

###############################################
# CREATE_DOMAINS - List all domains
###############################################
create_domains() {
  printf "\ncreating ${PREFIX}_domains.json file...\n"
  read_pages "/v2/domains?results-per-page=100" "domains" "{domain_guid: .metadata.guid , name: .entity.name, internal: .entity.internal, owning_org_guid: .entity.owning_organization_guid}"
}

###############################################
# CREATE_ROUTES - List all routes
###############################################
create_routes() {
  printf "\ncreating ${PREFIX}_routes.json file...\n"
  read_pages "/v2/routes?results-per-page=100" "routes" "{route_guid: .metadata.guid , host: .entity.host, path: .entity.path, domain_guid: .entity.domain_guid, space_guid: .entity.space_guid, service_instance_guid: .entity.service_instance_guid, port: .entity.port}"
}

###############################################
# CREATE_ROUTE_MAPPINGS - List all route mappings
###############################################
create_route_mappings() {
  printf "\ncreating ${PREFIX}_route_mappings.json file...\n"
  read_pages "/v2/route_mappings?results-per-page=100" "route_mappings" "{guid: .metadata.guid , app_port: .entity.app_port, app_guid: .entity.app_guid, route_guid: .entity.route_guid}"
}
###############################################
# CREATE_APPS - List all apps into PREFIX_apps.json
###############################################
create_apps() {
  printf "\ncreating ${PREFIX}_apps.json file...\n"
  read_pages "/v2/apps?results-per-page=100" "apps" "{app_guid: .metadata.guid, name: .entity.name, memory: .entity.memory, disk_quota: .entity.disk_quota, state: .entity.state, instances: .entity.instances, buildpack:  (if .entity.buildpack == null then .entity.detected_buildpack else .entity.buildpack end), buildpack_guid: .entity.detected_buildpack_guid, space: .entity.space_guid, updated: .entity.package_updated_at}"
}

###############################################
# CREATE_APP_SRV_BINDINGS - get apps binding
###############################################
create_app_srv_bindings() {

non_system_app TRUE

# echo "******* appguids - ${PREFIX}_final_apps.json"
apps_guids=$(cat ${PREFIX}_final_apps.json | jq -r ".apps[].app_guid")
rm ${PREFIX}_final_apps.json

# printf '%s\n' "${apps_guids[@]}"
total_apps=$(echo "${apps_guids[@]}" | wc -l)

printf "\nGenerating non system apps service bindings...\n\n"
c=0
while read -r line; do
    read_pages "/v2/apps/${line}/service_bindings?results-per-page=100" "apps_srv_binding_${c}" "{app_guid: .entity.app_guid, service_instance_guid: .entity.service_instance_guid, service_name: .entity.name}" TRUE
    c=$((c + 1))
    echo -ne "Apps read so far ${c} of ${total_apps}\r"
done <<< "$apps_guids"
printf "\nSearched for service bindings for ${c} apps.\n\n"

# Combine each app service bindings
jq --slurp . ${PREFIX}_apps_srv_binding_*.json > ${PREFIX}_apps_srv_binding.bkp
rm ${PREFIX}_apps_srv_binding_*.json 
mv ${PREFIX}_apps_srv_binding.bkp ${PREFIX}_apps_srv_binding.json
echo "Done. Created file ${PREFIX}_apps_srv_binding.json"

}

###############################################
# COMBINE_FILES Combine all json files into prefix_foundation.json
###############################################
combine_files() {

  TIMESTAMP=`date -u +%Y-%m-%dT%H:%M:%SZ`

  echo "{ \"metadata\": [ {\"version\": \"0.0.1\", \"captured_date\": \"${TIMESTAMP}\"} ] }" >  ${PREFIX}_version.json

  jq --slurp . ${PREFIX}_*.json > ${PREFIX}_foundation.bkp
  rm ${PREFIX}_*.json 
  mv ${PREFIX}_foundation.bkp ${PREFIX}_foundation_${TIMESTAMP}.json

  
  printf "\nCombined them into ${PREFIX}_foundation_${TIMESTAMP}.json - I'm happy with this file.\n\n"
}


###############################################
# Helper functions
###############################################
jq_exists() {
  command -v jq >/dev/null 2>&1
}

error_and_exit() {
  echo "$1" && exit 1
}

###############################################
########## RUNNING ###############
###############################################

if [ "$#" -lt 1 ]; then
    usage_and_exit
fi

if ! jq_exists; then
    error_and_exit "jq command not found. Please install jq to support set-vm-type functionality (https://stedolan.github.io/jq/download/)"
fi

PREFIX=${1:-}
CMD=${2:-ALL}

CMD=$( tr '[:lower:]' '[:upper:]' <<< "$CMD" )
echo "options: PREFIX: $PREFIX, CMD: $CMD"

if [ "$CMD" == "SRVS" ]; then
  create_app_srv_bindings
elif [ "$CMD" == "APPS" ]; then
    create_csv
elif [ "$CMD" == "ALL" ]; then
  # Created foundation file, needed for CSV step below
  create_info
  create_orgs
  create_spaces
#  create_users
  create_apps
  create_services
  create_service_plans
  create_service_instances
  create_user_provided_service_instances
  create_service_bindings
  create_domains
  create_routes
  create_route_mappings
  combine_files
else 
  echo "Invalid command $CMD"
  exit 1
fi
