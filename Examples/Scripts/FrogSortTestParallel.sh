#!/usr/bin/env bash

set -eo pipefail


options=`getopt -o '' -l task:,Subject:,StudyFolder:,Name:,help -- $@`
eval set -- "$options"

function display_help() {
    echo "Usage: `basename $0` [options...]"
    echo "	Required:"
    echo "      --task           task number is also number of flies"
    echo "      --Subject        subject id number"
    echo "      --StudyFolder    full path to study directory"
    echo "      --Name           name of node"
    echo ""
    echo "  documentation found here for frog sort:"
    echo "  https://www.smbc-comics.com/?id=2831  "
    exit 1;
}

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        --task)
          TN="$2"
          shift 2
        ;;
        --Subject)
          ID="$2"
          shift 2
        ;;
        --StudyFolder)
          SF="$2"
          shift 2
          ;;
        --Name)
            NODENAME="$2"
            shift 2
            ;;
        --help)
          display_help;;
        --) shift ; break ;;
        *) echo "Unexpected error parsing args" ; display_help 1 ;;
    esac
done

if [ -z "$TN" ] || [ -z "$ID" ] || [ -z "$SF" ] ; then
    display_help;
fi

DIR=${SF}/${ID}/${NODENAME}
set -x
mkdir -p ${DIR}
sleep ${TN}
touch ${DIR}/${TN}
echo ${TN} >> ${DIR}/sorted.txt
