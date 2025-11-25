#!/bin/bash
#

#Variable
readonly SCRIPT=$(realpath -s $0)
readonly SCRIPT_NAME=${0/%.*/}
readonly SCRIPT_HOME=${SCRIPT%/*}
readonly SCRIPT_SOURCE=${SCRIPT_HOME}/data/
readonly SCRIPT_ARCHIVE=${SCRIPT_HOME}/archive/


readonly PROJECT_EXPORT="virtualys libaly"

#Message
readonly RED="\e[1;91m"
readonly BLUE="\e[1;34m"
readonly GREEN="\e[1;92m"
readonly YELLOW="\e[0;33m"
readonly RESET="\e[0m"

readonly INFO="[${BLUE}INFO${RESET}]"
readonly OK="[${GREEN}OK${RESET}]"
readonly KO="[${RED}KO${RESET}]"
readonly DEBUG="[${YELLOW}DEBUG${RESET}]"


#Function

_say () {
    local target message
    target=${1}
    message=${2}
    case "$target" in
        info|i) echo -e "$INFO $message";;
        ko|k) echo -e "$KO $message";;
        ok|o) echo -e "$OK $message";;
        debug|d) echo -e "$DEBUG $message";;
    esac
}

_check_source () {

    source=${1}

    if [[ ! -d $SCRIPT_SOURCE ]]
    then
        _say k "Le répertoire source n'existe pas"
        exit 1
    fi
}

_mk_archive () {
    
    export archive_name=${1:-archive}

    if [ -d $SCRIPT_ARCHIVE ]
    then
        _say o "Suppression de l'ancien répertoire d'archive"
        rm -rf $SCRIPT_ARCHIVE
        _say o "Création d'un répertoire d'archive vierge"
        mkdir -p $SCRIPT_ARCHIVE
    fi

    if [ -e $archive_name.tar.zst ]
    then
        _say i "Suppression de l'ancienne $archive_name.tar.zst"
        echo "rm $archive_name.tar.zst"
    fi

    for project in $PROJECT_EXPORT
    do
        _say o "Copie des sources du projet $project"
        cp -v ${SCRIPT_SOURCE%/}/${project}/*.whl ${SCRIPT_ARCHIVE}
    done

}

_tar_archive () {

    _say i "Création de l'archive $archive_name.tar.zst"
    tar -caf ${SCRIPT_HOME%/}/${archive_name}.tar.zst $SCRIPT_ARCHIVE

}

#Main

_check_source $SCRIPT_SOURCE

_say i "Création de l'archive à exporter"

_mk_archive 

_tar_archive







