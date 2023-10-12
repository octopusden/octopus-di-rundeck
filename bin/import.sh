#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "${0}")")"
source "${SCRIPT_DIR}/bash_utils.sh"

check_var SCRIPT_DIR

# check RD is installed
echo_info "Checking RD is installed..."
RD_CLI_VERSION="$(rd --version)"
check_retcode
echo_info "RD CLI version: ${RD_CLI_VERSION}"

RUNDECK_PORT="4440"
check_var RUNDECK_PORT
check_var RUNDECK_ADMIN_USER
check_var RUNDECK_ADMIN_PASSWORD Y

RD_URL="http://localhost:${RUNDECK_PORT}"
check_var RUNDECK_GRAILS_URL
export RD_URL
export RD_USER="${RUNDECK_ADMIN_USER}"
export RD_PASSWORD="${RUNDECK_ADMIN_PASSWORD}"
export RD_AUTH_PROMPT=false
export RD_COLOR=0
export RD_BYPASS_URL="${RUNDECK_GRAILS_URL}"
export RD_HTTP_CONN_TIMEOUT=300
check_var RD_URL
check_var RD_BYPASS_URL
check_var RD_USER
check_var RD_PASSWORD Y

echo_info "Waiting until RUNDECK is available..."
ATTEMPTS_CURR=0
LIMIT_ATTEMPTS=33
RD_CONNECT_ERROR="/tmp/rd_connect.log"
rm -rvf "${RD_CONNECT_ERROR}"

while [ /bin/true ]
do
    echo_info "Attempt ${ATTEMPTS_CURR} of ${LIMIT_ATTEMPTS}"
    RD_SYS_INFO="$(rd system info 2>"${RD_CONNECT_ERROR}")"
    RETCODE="${?}"

    if (( RETCODE == 0 ))
    then
        check_var RD_SYS_INFO
        break
    fi

    (( ATTEMPTS_CURR++ ))

    if (( ATTEMPTS_CURR == LIMIT_ATTEMPTS ))
    then
        echo_error "Unable to contact RunDeck"
        echo_error "$(cat "${RD_CONNECT_ERROR}")"
        exit ${RETCODE}
    fi

    echo_info "Failed, sleeping 10s..."
    sleep 10

done

test -z "${RUNDECK_HOME}" && RUNDECK_HOME="/home/rundeck"
check_var RUNDECK_HOME
check_dir "${RUNDECK_HOME}"

### Adding/updating SSH keys
RUNDECK_SSH_KEYS_DIR="${RUNDECK_HOME}/etc/ssh-keys"
check_var RUNDECK_SSH_KEYS_DIR
check_dir "${RUNDECK_SSH_KEYS_DIR}"

for RUNDECK_SSH_KEY_FILE in "${RUNDECK_SSH_KEYS_DIR}"/*.priv.key
do
    check_var RUNDECK_SSH_KEY_FILE
    check_file "${RUNDECK_SSH_KEY_FILE}"
    RUNDECK_INT_KEY_PATH="keys/$(basename "${RUNDECK_SSH_KEY_FILE}" | awk '{sub(/\.priv\.key$/, ".sec"); print}')"
    check_var RUNDECK_INT_KEY_PATH

    # here is a fork
    # if a key exists then update it
    # add it otherwise
    KCMD="update"
    KEY_EXIST="$(rd keys list --path="${RUNDECK_INT_KEY_PATH}")"
    test -z "${KEY_EXIST}" && KCMD="create"
    check_var KCMD
    rd keys "${KCMD}" --file="${RUNDECK_SSH_KEY_FILE}" --path="${RUNDECK_INT_KEY_PATH}" --type=privateKey
done

### adding/updating passwords from environment variables

for RUNDECK_INT_KEY_PATH in $(env | grep -P '^[^=]+=' | awk -F '=' '{print $1}' | grep -P '_PASSWORD$')
do
    RUNDECK_INT_KEY_VALUE="$(get_var_val "${RUNDECK_INT_KEY_PATH}")"
    RUNDECK_INT_KEY_PATH="keys/${RUNDECK_INT_KEY_PATH}"
    check_var RUNDECK_INT_KEY_PATH
    check_var RUNDECK_INT_KEY_VALUE Y

    # unfortunately RD CLI supports to read password key from file only
    # we have to write it

    RUNDECK_PASSWD_KEY_FILE='/tmp/passwdkey'
    echo "${RUNDECK_INT_KEY_VALUE}" > "${RUNDECK_PASSWD_KEY_FILE}"

    # check such a key exists
    # if a key exists then update it
    # add it otherwise
    KCMD="update"
    KEY_EXIST="$(rd keys list --path="${RUNDECK_INT_KEY_PATH}")"
    test -z "${KEY_EXIST}" && KCMD="create"
    check_var KCMD
    rd keys "${KCMD}" --file="${RUNDECK_PASSWD_KEY_FILE}" --path="${RUNDECK_INT_KEY_PATH}" --type=password
    rm -rvf "${RUNDECK_PASSWD_KEY_FILE}"
done

### Adding/updating projects
RUNDECK_PROJECTS_DIR="${RUNDECK_HOME}/etc/projects"
check_var RUNDECK_PROJECTS_DIR
check_dir "${RUNDECK_PROJECTS_DIR}"

for RUNDECK_PROJECT_DIR in "${RUNDECK_PROJECTS_DIR}"/*
do
    check_var RUNDECK_PROJECT_DIR
    test -d "${RUNDECK_PROJECT_DIR}" || continue
    RUNDECK_PROJECT_PROPS_FILE="${RUNDECK_PROJECT_DIR}/project.properties"
    check_var RUNDECK_PROJECT_PROPS_FILE
    check_file "${RUNDECK_PROJECT_PROPS_FILE}"
    RUNDECK_PROJECT_NAME="$(basename "$(dirname "${RUNDECK_PROJECT_PROPS_FILE}")")"
    check_var RUNDECK_PROJECT_NAME

    # create or update?
    KCMD="configure update"
    PROJECT_EXISTS="$(rd projects list --outformat='%name' | grep '^'"${RUNDECK_PROJECT_NAME}"'$')"
    test -z "${PROJECT_EXISTS}" && KCMD="create"
    rd projects ${KCMD} --project="${RUNDECK_PROJECT_NAME}" --file="${RUNDECK_PROJECT_PROPS_FILE}"

    # NODES should be set in properties file, no need to add separately
    # configuring SCM
    RUNDECK_SCM_CONFIG_FILE="${RUNDECK_PROJECT_DIR}/scm-config.json"
    check_var RUNDECK_SCM_CONFIG_FILE
    check_file "${RUNDECK_SCM_CONFIG_FILE}"

    echo_info "Setting up SCM..."
    rd projects scm setup --file="${RUNDECK_SCM_CONFIG_FILE}" --integration="import" --type="git-import" --project="${RUNDECK_PROJECT_NAME}"
    echo_info "Enabling SCM..."
    rd projects scm enable --integration="import" --type="git-import" --project="${RUNDECK_PROJECT_NAME}"
    #### NOTE: this is not actually working due to (https://github.com/rundeck/rundeck-cli/issues/518)
    ####    and thus temporary commented
    #rd projects scm status --integration="import" --project="${RUNDECK_PROJECT_NAME}"
    #check_retcode

done
