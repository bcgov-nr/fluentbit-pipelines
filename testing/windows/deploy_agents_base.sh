#!/usr/bin/env bash
set +x
export CD_USER=$(vault kv get -field=username_domainless groups/appdelivery/oraapp_imborapp)
export CD_PASS=$(vault kv get -field=password groups/appdelivery/oraapp_imborapp)
export HOST="stress.dmz"
export FB_FLUENTBIT_RELEASE="1.9.6"
export FB_TMP_DIR="E:/tmp/fluent-bit.testing"
export FB_BIN_DIR="E:/sw_nt"
export FB_AGENT_ROOT="E:/apps_nt/agents"
export HTTP_PROXY=""
export FB_VAULT_RELEASE="1.10.4"
export FB_ENVCONSUL_RELEASE="0.12.1"
export FB_JQ_RELEASE="1.6"
export FB_SQLITE_RELEASE="3.38.5"
export FB_WINSW_RELEASE="v2.11.0"

# Strip last decimal/digit from fluent bit release
# Needed for fluent bit release curl URL
# https://unix.stackexchange.com/questions/250740/replace-string-after-last-dot-in-bash
FB_FLUENTBIT_RELEASE_MAJOR_MINOR="${FB_FLUENTBIT_RELEASE%.*}"

sshpass -p $FB_CD_PASS ssh -q $FB_CD_USER@$FB_HOST powershell.exe -Command -<<EOF
echo "Temp directory: $FB_TMP_DIR"
# create bin directories and agent root
New-Item -ItemType "directory" -Path "$FB_BIN_DIR/vault" -Force
New-Item -ItemType "directory" -Path "$FB_BIN_DIR/envconsul" -Force
New-Item -ItemType "directory" -Path "$FB_BIN_DIR/jq" -Force 
New-Item -ItemType "directory" -Path "$FB_BIN_DIR/sqlite" -Force
New-Item -ItemType "directory" -Path "$FB_AGENT_ROOT" -Force
New-Item -ItemType "directory" -Path "E:/apps_data/agents/fluent-bit" -Force
New-Item -ItemType "directory" -Path "E:/logs/agents/fluent-bit" -Force

# download dependencies
if ("$HTTP_PROXY".Length -gt 0) {
  # Set tls
  # Needed for Invoke-WebRequest to succeed
  # https://stackoverflow.com/questions/25143946/powershell-3-0-invoke-webrequest-https-fails-on-all-requests/25163476#25163476
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Proxy $HTTP_PROXY -Uri "https://releases.hashicorp.com/vault/${FB_VAULT_RELEASE}/vault_${FB_VAULT_RELEASE}_windows_amd64.zip" -OutFile "$FB_TMP_DIR/bin/vault.zip"
  Invoke-WebRequest -Proxy $HTTP_PROXY -Uri "https://releases.hashicorp.com/envconsul/${FB_ENVCONSUL_RELEASE}/envconsul_${FB_ENVCONSUL_RELEASE}_windows_amd64.zip" -OutFile "$FB_TMP_DIR/bin/envconsul.zip"
  Invoke-WebRequest -Proxy $HTTP_PROXY -Uri "https://github.com/stedolan/jq/releases/download/jq-${FB_JQ_RELEASE}/jq-win64.exe" -OutFile "$FB_BIN_DIR/jq/jq-win64.exe"
  Invoke-WebRequest -Proxy $HTTP_PROXY -Uri "https://fluentbit.io/releases/${FB_FLUENTBIT_RELEASE_MAJOR_MINOR}/fluent-bit-${FB_FLUENTBIT_RELEASE}-win64.zip" -OutFile "$FB_TMP_DIR/bin/fluent-bit.zip"
  Invoke-WebRequest -Proxy $HTTP_PROXY -Uri "https://www.sqlite.org/2022/sqlite-tools-win32-x86-3390300.zip" -OutFile "$FB_TMP_DIR/bin/sqlite.zip"
  Invoke-WebRequest -Proxy $HTTP_PROXY -Uri "https://github.com/winsw/winsw/releases/download/${FB_WINSW_RELEASE}/WinSW-x64.exe" -OutFile "$FB_TMP_DIR/bin/WinSW-x64.exe"
} else {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri "https://releases.hashicorp.com/vault/${FB_VAULT_RELEASE}/vault_${FB_VAULT_RELEASE}_windows_amd64.zip" -OutFile "$FB_TMP_DIR/bin/vault.zip"
  Invoke-WebRequest -Uri "https://releases.hashicorp.com/envconsul/${FB_ENVCONSUL_RELEASE}/envconsul_${FB_ENVCONSUL_RELEASE}_windows_amd64.zip" -OutFile "$FB_TMP_DIR/bin/envconsul.zip"
  Invoke-WebRequest -Uri "https://github.com/stedolan/jq/releases/download/jq-${FB_JQ_RELEASE}/jq-win64.exe" -OutFile "$FB_BIN_DIR/jq/jq-win64.exe"
  Invoke-WebRequest -Uri "https://fluentbit.io/releases/${FB_FLUENTBIT_RELEASE_MAJOR_MINOR}/fluent-bit-${FB_FLUENTBIT_RELEASE}-win64.zip" -OutFile "$FB_TMP_DIR/bin/fluent-bit.zip"
  Invoke-WebRequest -Uri "https://www.sqlite.org/2022/sqlite-tools-win32-x86-3390300.zip" -OutFile "$FB_TMP_DIR/bin/sqlite.zip"
  Invoke-WebRequest -Uri "https://github.com/winsw/winsw/releases/download/${FB_WINSW_RELEASE}/WinSW-x64.exe" -OutFile "$FB_TMP_DIR/bin/WinSW-x64.exe"
}

# deploy tools
Expand-Archive -Path "$FB_TMP_DIR/bin/vault.zip" -DestinationPath "$FB_TMP_DIR/bin" -Force
Move-Item -Path "$FB_TMP_DIR/bin/vault.exe" -Destination "$FB_BIN_DIR/vault" -Force
Expand-Archive -Path "$FB_TMP_DIR/bin/envconsul.zip" -DestinationPath "$FB_TMP_DIR/bin" -Force
Move-Item -Path "$FB_TMP_DIR/bin/envconsul.exe" -Destination "$FB_BIN_DIR/envconsul" -Force
Expand-Archive -Path "$FB_TMP_DIR/bin/sqlite.zip" -DestinationPath "$FB_TMP_DIR/bin" -Force
Move-Item -Path "$FB_TMP_DIR/bin/sqlite-tools-win32-x86-3390300/*" -Destination "$FB_BIN_DIR/sqlite" -Force

# deploy fluent bit
Expand-Archive -Path "$FB_TMP_DIR/bin/fluent-bit.zip" -DestinationPath "$FB_TMP_DIR/bin" -Force
\$AGENTS = (Get-ChildItem -Directory -Path "$FB_TMP_DIR/output/fluent-bit.*" -Name)

if (\$AGENTS.count -gt 0) {
  Foreach (\$i in \$AGENTS) {
    \$AGENT = \$i
    \$AGENT_HOME = "$FB_AGENT_ROOT/\$AGENT"
    New-Item -ItemType "directory" -Path "\$AGENT_HOME" -Force
    Copy-Item -Path "$FB_TMP_DIR/bin/fluent-bit-${FB_FLUENTBIT_RELEASE}-win64/*" -Destination "\$AGENT_HOME" -Recurse -Force
    Copy-Item -Path "$FB_TMP_DIR/output/\$AGENT/*" -Destination "\$AGENT_HOME/conf" -Recurse -Force
    # generate fluent-bit.hcl
    Get-Content "$FB_TMP_DIR/files/fluent-bit.hcl" | % {
      \$_.replace("{{ apm_agent_home }}/bin/fluent-bit -c {{ apm_agent_home }}/conf/fluent-bit.conf","\$AGENT_HOME/bin/fluent-bit.exe -c \$AGENT_HOME/conf/fluent-bit.conf").
      replace('HTTP_PROXY=\$HTTP_PROXY', "HTTP_PROXY=$HTTP_PROXY")
    } | Set-Content "\$AGENT_HOME/conf/fluent-bit.hcl" -Force
  }  
} else {
  throw "No agents found for deployment"
}

EOF
