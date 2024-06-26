#!/usr/bin/env bash

if [ -z "$1" ]
  then
    echo "No license plate supplied"
fi

if [ -z "$2" ]
  then
    echo "No environment supplied"
fi

if [ -n "$1" ] && [ -n "$2" ]
  then
  export VAULT_ADDR="https://vault-iit-$2.apps.silver.devops.gov.bc.ca"
  export FB_BROKER_URL="https://nr-broker-$2.apps.silver.devops.gov.bc.ca"
  if [ "prod" = $2 ]
  then
    export VAULT_ADDR="https://knox.io.nrs.gov.bc.ca"
    export FB_BROKER_URL="https://broker.io.nrs.gov.bc.ca"
  fi
  VAULT_TOKEN=$(vault login -method=oidc -format json -tls-skip-verify | jq -r '.auth.client_token')
  export FB_CONFIG_ROLE_ID=$(vault read -format json auth/vs_apps_approle/role/jenkins_jenkins-isss_prod/role-id | jq -r '.data.role_id')
  export FB_ROLE_ID=$(vault read -format json auth/vs_apps_approle/role/fluent_fluent-bit_prod/role-id | jq -r '.data.role_id')

  export BASIC_HTTP_USER=$(oc get secret nr-broker-basic-creds -n $1-$2 -o go-template --template="{{.data.user|base64decode}}")
  export BASIC_HTTP_PASSWORD=$(oc get secret nr-broker-basic-creds -n $1-$2 -o go-template --template="{{.data.password|base64decode}}")
fi
