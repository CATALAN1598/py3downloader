#!/bin/bash
#

#Variable
readonly SCRIPT=$(realpath -s $0)
readonly SCRIPT_NAME=${0/%.*/}
readonly SCRIPT_HOME=${SCRIPT%/*}
readonly SCRIPT_DATA=${SCRIPT_HOME}/data/
readonly SCRIPT_ARCHIVE=${SCRIPT_HOME}/archive/


readonly SCRIPT_PEER_PACKAGE=${SCRIPT_HOME}/.peer_package/

readonly PROJECT_EXPORT="virtualys libaly"
ARCHIVE_NAME="archive-test"
ARCHIVE_EXTENTION="tar.zst"

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

    local source

    for source in "$@"
    do
        if [[ ! -d ${source} ]]
        then
            _say k "Le répertoire ${source} n'existe pas"
            exit 1
        fi
    done
}

_check_directories () {

    local directory
 
    for directory in "$@"
    do
        if [ ! -d $directory ] 
        then 
            _say d "Création du repertoire ${directory}"
            mkdir -p ${directory}
        else
            _say o "Le répertoire $directory existe"
        fi
    done


}

_add_content_to_archive_source () {

    local destination
    destination=${1}
    shift
    
    for source_dir in "$@"
    do
        _say i "Génération des librairies sources de l'archive"
        find "${source_dir}" \( -name "*.whl" -o -name "*.tar.gz" \) -type f -exec cp {} "${destination}/" \;
    done
   
}

_make_archive () {

    local option=${1}
    local source_dir=${2}
    local archive_name=${3}
    local extention=${4}

    local archive_full_name=${archive_name}.${extention}
    local destination=${SCRIPT_HOME%/}/${archive_full_name}

    if [ "$#" -ne 4 ]
    then
        _say k "_make_archive à besion de 4 argument
        1: option -d ou -f (directory ou file)
        2: Source de travail
        3: Nom de l'archive
        4: Extention voulu"
        exit 1
    fi

    case $option in
        -d) _say i "Création de l'archive $archive_full_name avec pour répertoire source $source_dir" 
            tar -caf ${destination} $(basename ${source_dir})
        ;;
        -f)
            _say i "Création de l'archive $archive_full_name avec les fichiers de $source_dir" 
            cd ${SCRIPT_ARCHIVE} ; tar -caf ${destination} *; cd ${SCRIPT_HOME} 
        ;;
         *) _say k "Choix invalide"
            exit 1
         ;;
    esac
  
}
#Main

_check_source "${SCRIPT_DATA}"

_check_directories ${SCRIPT_ARCHIVE}

for project in $PROJECT_EXPORT; do _add_content_to_archive_source "${SCRIPT_ARCHIVE}" "${SCRIPT_DATA%/}/${project}/"; done

if [ -e ${ARCHIVE_NAME:-archive}.${ARCHIVE_EXTENTION:-tar.zst} ]; then _say i "Suppression de l'archive précédente" ; rm  ${ARCHIVE_NAME:-archive}.${ARCHIVE_EXTENTION:-tar.zst}; fi

_make_archive -f ${SCRIPT_ARCHIVE} ${ARCHIVE_NAME:-archive} ${ARCHIVE_EXTENTION:-tar.zst} 

_make_archive -d ${SCRIPT_PEER_PACKAGE} peer_package tar.zst

_say i "Script terminé"





 