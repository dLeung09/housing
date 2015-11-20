#!/bin/bash

COLOR_RED='\x1b[31;01m'
COLOR_BLUE='\x1b[34;01m'
COLOR_NONE='\x1b[0m'


CURR_DIR="$(dirname "$(readlink -e "${0}")")"
SCRIPT="${CURR_DIR}/house_parse.pl"

echo_blue()
{
    echo -n -e "${COLOR_BLUE}"
    echo "${@}"
    echo -n -e "${COLOR_NONE}"
}

echo_red()
{
    echo -n -e "${COLOR_RED}"
    echo "${@}"
    echo -n -e "${COLOR_NONE}"
}

extract_data()
{
}

mine_data()
{
    local INPUT_FILE="${1}"
    local OUTPUT_FILE="${2}"

    perl "${SCRIPT}" "${INPUT_FILE}" "${OUTPUT_FILE}"
}

loop_thru_search()
{
}

loop_thru_search
