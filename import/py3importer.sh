#!/bin/bash
#

#Variable
readonly SCRIPT=$(realpath -s $0)
readonly SCRIPT_NAME=${0/%.*/}
readonly SCRIPT_HOME=${SCRIPT%/*}
readonly SCRIPT_CONF=${SCRIPT_HOME}/${SCRIPT_NAME}.conf
readonly SCRIPT_VENV=${SCRIPT_HOME}/.venv/
readonly SCRIPT_DROP=${SCRIPT_HOME}/drop/
readonly SCRIPT_LIBS=${SCRIPT_HOME}/libs/

readonly BIN_VENV_PIP=${SCRIPT_VENV%/}/bin/pip
readonly BIN_VENV_ACT=${SCRIPT_VENV%/}/bin/activate
readonly BIN_PYTHON3=/usr/bin/python3

readonly BIN_TAR=/usr/bin/tar
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

source $SCRIPT_CONF



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

_check_apt_dependencies () {

    local dependencie

    for dependencie in "$@"
    do
        _say d "Vérification de la présence du package $dependencie prérequis de l'outil"
        if ! sudo apt list --installed 2> /dev/null | grep "$dependencie\/"
        then
            _say d "Le package $dependencie n'est pas installer et est un prérequis de l'outil"
            _say i "Installation de $dependencie"
            if ! sudo apt install $dependencie -y  ; then _say k "Installation echoué pour le package $dependencie"; exit 1; fi
            #if [ "$?" -ne "0" ]; then _say k "Installation echoué pour le package $dependencie"; exit 1; fi
        else
            _say o "Le package $dependencie est déjà installé."
        fi
    done
}

_check_virtualenv () {

    if [ ! -d ${SCRIPT_VENV} ]
    then
        _say d "Aucun environnement virtuel présent pour l'outil"
        _say i "Création d'un environnement virtuel pour l'outil"
        $BIN_PYTHON3 -m venv ${SCRIPT_VENV}
    else
        _say i "Un environnement virtuel est configuré dans ${SCRIPT_VENV}"
    fi

    if [[ -e $BIN_VENV_ACT && -e $BIN_VENV_PIP ]]
    then
        _say i "Les outils python3 de l'environnement virtuel sont présent"
    else
        _say k "Les outils python3 de l'environnement virtuel ne sont pas présent"
        _say d "Supprimer l'environnement virtuel (rm -rf ${SCRIPT_VENV}) puis relancer $0"
        exit 1
    fi
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
            _say d "Le répertoire $directory existe"
        fi
    done


}

_untar_archive () {

    for archive in ${SCRIPT_DROP%/}/*.tar.zst
    do
        _say i "Extraction de l'archive $archive dans $SCRIPT_LIBS"
        $BIN_TAR -xvaf ${archive} -C ${SCRIPT_LIBS}
    done

}

_clear_dest () {
    local target=${1}
    while true
    do
        read -p "Voulez-vous effacer le contenu de ${target} (défaut: non) ? (oO/nN): " -t 30 choix  
        [ -z ${choix} ] && choix=n
        case $choix in
            o|O) _say i "Nettoyage de ${target}"
                 echo "rm ${SCRIPT_HOME%/}/${target}/*"; return 0;;
                 
            n|N) _say k "Annulation du nettoyage de ${target}"; exit 1;;
              *) _say k "Choix invalide"; exit 1;;
        esac 
    done
}

#Main

_check_directories "drop" "libs"

_clear_dest "libs"

_untar_archive 
