#!/bin/bash


# start rundeck
SCRIPT_DIR="$(dirname "$(readlink -f "${0}")")"
test ! -f "${SCRIPT_DIR}/bash_utils.sh" && echo "ERROR: Not found: ${SCIPT_DIR}/bash_utils.sh" && exit 1
source "${SCRIPT_DIR}/bash_utils.sh"

check_var SCRIPT_DIR

test [ "$(pwd)" != "/home/rundeck" ] && echo_error "Wrong directory. Please run this from /home/rundeck" && exit 1

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

check_file "${SCRIPT_DIR}/add_projects.sh"
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


"${SCRIPT_DIR}/add_projects.sh"
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
