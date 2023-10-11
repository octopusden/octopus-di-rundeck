#!/bin/bash

#####BEG: Additional Functions
function echo_info() {
    echo "${0}: INFO: ${1}"
}

function echo_error() {
    echo "${0}: ERROR: ${1}"
}

function get_var_val() {
    local VAL
    eval "VAL=\"\${$(echo ${1})}\""
    echo -n "${VAL}"
}

function check_var() {
    VAR_NAM="${1}"
    VAR_VAL=$(get_var_val "${VAR_NAM}");
    VAR_PASS="${2}"
    
    if [ -z "${VAR_VAL}" ]
    then
        echo_error "Variable not set: ${VAR_NAM}"
        exit 1
    fi

    DISP_VAL="\"${VAR_VAL}\""

    if [ "${VAR_PASS}" == "Y" ]
    then
        DISP_VAL="*******"
    fi

    echo_info "${VAR_NAM} = ${DISP_VAL}"
}

function check_retcode() {
    RET="${?}"
    if (( RET != 0 ))
    then
        echo_error "last process returned code ${RET}"
        exit "${RET}"
    fi

    echo_info "Return code is ${RET}"
}

function check_file() {
    if [ ! -e "${1}" ]
    then
        echo_error "File ${1} does not exist"
        exit 1
    fi

    if [ ! -f "${1}" ]
    then
        echo_error "File ${1} is not a file"
        exit 1
    fi

    if [ ! -r "${1}" ]
    then
        echo_error "File ${1} is not readable"
        exit 1
    fi
}

function check_dir() {
    if [ ! -e "${1}" ]
    then
        echo_error "Directroy ${1} does not exist"
        exit 1
    fi

    if [ ! -d "${1}" ]
    then
        echo_error "Directory ${1} is not a folder"
        exit 1
    fi

    if [ ! -r "${1}" ]
    then
        echo_error "Directory ${1} is not readable"
        exit 1
    fi

    if [ ! -w "${1}" ]
    then
        echo_error "Directory ${1} is not writable"
        exit 1
    fi

    if [ ! -x "${1}" ]
    then
        echo_error "Directory ${1} is not allowed to read contents"
        exit 1
    fi
}
#####END: Additional Functions
