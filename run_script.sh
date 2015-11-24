#!/bin/bash

COLOR_RED='\x1b[31;01m'
COLOR_BLUE='\x1b[34;01m'
COLOR_NONE='\x1b[0m'


CURR_DIR="$(dirname "$(readlink -e "${0}")")"
RESULTS_DIR="${CURR_DIR}/results"
SCRIPT="${CURR_DIR}/house_parse.pl"

#URL="https://listingservice.housing.queensu.ca/index.php/rental/rentalsearch/action/results_list/pageID/[1-10]/"
URL="https://listingservice.housing.queensu.ca/index.php/rental/rentalsearch/action/results_list/pageID/1/"

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

#extract_data()
#{
#}

mine_data()
{
    local INPUT_FILE="${1}"
    local OUTPUT_FILE="${2}"

    perl "${SCRIPT}" "${INPUT_FILE}" "${OUTPUT_FILE}"
}

loop_thru_search()
{
    #curl "${URL}" -o "#1_#2"
    curl https://listingservice.housing.queensu.ca/index.php/rental/rentalsearch/action/results_list/pageID/[1-10]/ > "results_#1.txt"
}

if ! test -e "${SCRIPT}" ; then
    echo_red "Cannot find the \"${SCRIPT}\" script."
    exit 1
fi

loop_thru_search

