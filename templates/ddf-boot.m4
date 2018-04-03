#!/bin/bash

# m4_ignore(
echo "This is just a script template, not the script (yet) - pass it to 'argbash' to fix this." >&2
exit 11  #)Created by argbash-init v2.6.1
# ARG_OPTIONAL_BOOLEAN([disable-security], [s], [Disable security manager])
# ARG_OPTIONAL_SINGLE([https-port], [p], [Set https port for ddf instance], [8993])
# ARG_OPTIONAL_SINGLE([http-port], [P], [Set http port for ddf instance], [8181])
# ARG_OPTIONAL_SINGLE([profile], [], [Installation profile])
# ARG_OPTIONAL_BOOLEAN([debug-mode], [d], [Enables karaf debug mode])
# ARG_OPTIONAL_BOOLEAN([interactive-client], [i], [Start a client session after system boots])
# ARG_POSITIONAL_SINGLE([ddf-directory], [Directory where ddf instance is located], [$(pwd)])
# ARG_DEFAULTS_POS
# ARG_HELP([Bootstrap a ddf node from an unzipped ddf archive)])
# ARGBASH_GO

# [ <-- needed because of Argbash 

_ddf_bin=${_arg_ddf_directory}/bin
_ddf_etc=${_arg_ddf_directory}/etc
_ddf_data=${_arg_ddf_directory}/data
_distro_name=$(basename ${_arg_ddf_directory} | cut -f1 -d"-")
_client="${_ddf_bin}/client -r 12 -d 10"

function disableSecMgr {
  props del policy.provider ${_ddf_etc}/system.properties
  props del java.security.manager ${_ddf_etc}/system.properties
  props del java.security.policy ${_ddf_etc}/system.properties
  props del proGrade.getPermissions.override ${_ddf_etc}/system.properties
}

function configureHost {
  echo "Configuring Host Specific properties for hostname $(hostname -f)"
  props set org.codice.ddf.system.hostname $(hostname -f) ${_ddf_etc}/system.properties
  props del localhost ${_ddf_etc}/users.properties
  props set $(hostname -f) "$(hostname -f),group,admin,manager,viewer,system-admin,system-history,systembundles" ${_ddf_etc}/users.properties
  sed -i '' "s/localhost/$(hostname -f)/" ${_ddf_etc}/users.attributes
}

function genCerts {
  echo -e "Generating certificates for $(hostname -f)\n\tCN: $(hostname -f)\n\tSAN: \n\t\tDNS:$(hostname -f),\n\t\tDNS:localhost,\n\t\tIP:127.0.0.1"
  chmod 755 ${_ddf_etc}/certs/*.sh
  ${_ddf_etc}/certs/CertNew.sh -cn $(hostname -f) -san "DNS:$(hostname -f),DNS:localhost,IP:127.0.0.1"
}

function setPorts {
  echo -e "Setting Up ports:\n\tHTTPS:${_arg_https_port}\n\tHTTP:${_arg_http_port}"
  props set org.codice.ddf.system.httpsPort ${_arg_https_port} ${_ddf_etc}/system.properties
  props set org.codice.ddf.system.httpPort ${_arg_http_port} ${_ddf_etc}/system.properties
}

function startSystem {
  echo "Starting System..."
  if [ "${_arg_debug_mode}" = on ]; then
    KARAF_DEBUG=true ${_ddf_bin}/start
  else
    ${_ddf_bin}/start
  fi
}

function waitForSystem {
  local _distro_log="${_ddf_data}/log/${_distro_name}.log"
  echo -n "Waiting for log file: ${_distro_log} to be created..."
  while [ ! -f ${_distro_log} ]
  do
    sleep 1
    echo -n "."
  done
  echo -e "\nLog file found, continuing..."
  echo "Waiting for system to finish starting..."
  sleep 5

  local _wfrStatus=1
  while [ ${_wfrStatus} -ne 0 ]
  do
    echo "Checking if ${_distro_name} is ready..."
    ${_client} "wfr"
    _wfrStatus=$?
  done
  if [ $_wfrStatus -ne 0 ]; then
    echo "Something went wrong checking for system start status, system may be unstable"
    return 1
  fi
  return 0
}

function profile {
  ${_client} "profile:install ${_arg_profile}"
}

function initialize {
  genCerts
  configureHost
  setPorts
}

function start {
  startSystem
  waitForSystem
  return $?
}

function main {
  initialize
  if [ "${_arg_disable_security}" = on ]; then
    disableSecMgr
  fi
  start
  if [ $? -ne 0 ]; then
    return ${_started}
  fi
  if [ ! -z "${_arg_profile}" ]; then
    profile
  fi
  if [ "${_arg_interactive_client}" = on ]; then
    echo "Starting interactive client session..."
    ${_client}
    return $?
  fi
  return 0
}

main
exit $?

# ] <-- needed because of Argbash