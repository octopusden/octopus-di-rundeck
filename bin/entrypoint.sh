#!/bin/bash


# start rundeck
SCRIPT_DIR="$(dirname "$(readlink -f "${0}")")"
test ! -f "${SCRIPT_DIR}/bash_utils.sh" && echo "ERROR: Not found: ${SCIPT_DIR}/bash_utils.sh" && exit 1
source "${SCRIPT_DIR}/bash_utils.sh"

check_var SCRIPT_DIR

test -z "$(pwd | grep -P '^\/home\/rundeck$')" && echo_error "Wrong directory. Please run this in /home/rundeck" && exit 1

function rd_stop() {
    local PIDS

    echo_info "Reached rd_stop"
    PIDS="$(ps ax | grep -v grep | grep -P '(tail|java)' | awk '{print $1}' | tr '\n' ' ')"
    SIGNAL=2
    echo_info "Current PIDs: ${PIDS}"

    while [ "${PIDS}" != "" ]
    do
        echo_info "Killing ${PIDS}"
        kill -${SIGNAL} ${PIDS}
        echo_info "Signal ${SIGNAL} sent, waiting 30s..."
        sleep 30
        PIDS="$(ps ax | grep -v grep | grep -P '(tail|java)' | awk '{print $1}' | tr '\n' ' ')"
        SIGNAL=9
    done
}

trap rd_stop SIGINT
trap rd_stop SIGHUP
trap rd_stop SIGKILL
trap rd_stop SIGTERM

check_file "${SCRIPT_DIR}/import.py"
check_file "${SCRIPT_DIR}/entry.sh"
OUTPUT="/dev/stdout"
check_var OUTPUT
echo_info "Starting rundeck in the background"
"/bin/bash" "${SCRIPT_DIR}/entry.sh" >> ${OUTPUT} 2>&1 &
echo_info "Waiting 150s until RUNDECK java process comes up..."
sleep 150

ATTEMPTS_CURR=0
LIMIT_ATTEMPTS=33
RUNDECK_PID=""

## wait until RUNDECK is started and became available
echo_info "Waiting until RUNDECK is starting..."
while [ -z "${RUNDECK_PID}" ]
do
    RUNDECK_PID="$(ps ax | grep -v grep | grep java | grep -i rundeck | awk '{print $1}' |  tr '\n' ' ')"
    echo_info "Attempt ${ATTEMPTS_CURR} of ${LIMIT_ATTEMPTS}: RUNDECK_PID is $(test -z "${RUNDECK_PID}" && echo "NOT set" || echo "${RUNDECK_PID}")"

    (( ATTEMPTS_CURR++ ))

    if (( ATTEMPTS_CURR == LIMIT_ATTEMPTS ))
    then
        echo_error "RUNDECK failed to startup during a given period"
        sleep 5
        rd_stop
        echo_info "Stopped"
        exit 1
    fi

    echo_info "$(test -z "${RUNDECK_PID}" && echo "Failed" || echo "Success"), sleeping 30s..."
    sleep 30

done

echo_info "Waiting until RUNDECK is available..."
ATTEMPTS_CURR=0
LIMIT_ATTEMPTS=33
RUNDECK_CONNECT_ERROR_FILE="/tmp/rundeck-connect-error"
rm -rf "${RUNDECK_CONNECT_ERROR_FILE}"

while [ /bin/true ]
do
    echo_info "Attempt ${ATTEMPTS_CURR} of ${LIMIT_ATTEMPTS}"

    # while Rundeck is starting it gives no answer on any request, because port is not opened
    # when Rundeck is ready it comes out with ERROR message on bulshit request
    # which contains an api_version as a key
    API_INFO_JSON="$(curl -X GET 'http://localhost:4440/api/unsupported' 2>"${RUNDECK_CONNECT_ERROR_FILE}")"
    RETCODE="${?}"

    test ! -z "$(echo "${API_INFO_JSON}" | grep 'apiversion' | grep -i "unsupported")" && echo_info "Got response: ${API_INFO_JSON}" && break

    (( ATTEMPTS_CURR++ ))

    if (( ATTEMPTS_CURR == LIMIT_ATTEMPTS ))
    then
        echo_error "Unable to connect to RunDeck instance, code is ${RETCODE}"
        echo_error "$(cat "${RUNDECK_CONNECT_ERROR_FILE}")"
        exit ${RETCODE}
    fi

    echo_info "Failed, sleeping 10s..."
    sleep 10

done

rm -rf "${RUNDECK_CONNECT_ERROR_FILE}"


# note: it is not nice to hardcode internal URL with port, but no way to override it 
# is provided by base image actually actually
python3 "${SCRIPT_DIR}/import.py" \
    --rundeck-url "http://localhost:4440" \
    --rundeck-user "${RUNDECK_ADMIN_USER}" \
    --rundeck-password "${RUNDECK_ADMIN_PASSWORD}"
RETCODE="${?}"

if (( RETCODE != 0 ))
then
    echo_error "Add project failed with ${RETCODE}, exiting..."
    rd_stop
    echo_info "Stopped"
    exit 1
fi

touch "/tmp/output"
tail -f "/tmp/output"
