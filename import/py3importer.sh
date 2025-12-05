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
readonly BIN_VENV_TWINE=${SCRIPT_VENV%/}/bin/twine

readonly BIN_PYTHON3=/usr/bin/python3
readonly BIN_TAR=/usr/bin/tar
readonly BIN_CURL=/usr/bin/curl


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

_check_python_dependencies () {

    local py3dep

    for py3dep in "$@"
    do
        if $BIN_VENV_PIP show ${py3dep} >/dev/null 2>&1; then
            _say i "${py3dep} est installé"
        else
            _say i "${py3dep} n'est  pas installé"
            _say i "Installation de ${py3dep}"
            if $BIN_VENV_PIP install ${py3dep} ; then _say i "Installation de ${py3dep} réussi"; else _say k "Erreur lors du téléchargement de ${py3dep}" ; exit 1 ; fi           
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
            _say i "Le répertoire $directory existe"
        fi
    done


}

_check_reachable_url () {
    local url=${1}

    code=$($BIN_CURL -s -w "%{http_code}" -o /dev/null $url)

    if [ $code -eq 200 ]
    then
        _say d "L'URL $url est joignable"
    else
        _say k "L'URL $url n'est pas joignable"
        exit 1
    fi 
}

_check_pylib_in_repo () {

    local repo_target=${1}
    local library=${2}
   
    export code

    declare -A lib

    lib[name]=$(echo $library | cut -d "-" -f1 | sed "s/_/-/g")
    lib[version]=$(echo $library | cut -d "-" -f2)
    #_say d "${lib[name]} ${lib[version]} $library"

    code=$(curl -s -u ${SERVER_USERNAME}:${SERVER_PASSWORD} -w "%{http_code}" -o /dev/null ${repo_target%/}/${lib[name]}/${lib[version]}/$library)
    #_say d "$library $code"
    
    if [ "$code" -eq 200 ]; then return 0 ; else return 1; fi
    
    
    
    #echo "curl -s -u ${SERVER_USERNAME}:${SERVER_PASSWORD} -w "%{http_code}" -o /dev/null" ${repo_target%/}/${lib[name]}/${lib[version]}/$library
    #http://127.0.0.1:8081/repository/PyPi-local/packages/certifi/2025.11.12/certifi-2025.11.12-py3-none-any.whl

}

_untar_archive () {

    for archive in ${SCRIPT_DROP%/}/*.tar.zst
    do
        _say i "Extraction de l'archive $archive dans $SCRIPT_LIBS"
        $BIN_TAR -xaf ${archive} -C ${SCRIPT_LIBS}
    done

}

_clear_dest () {
    local target=${1}
    while true
    do
        read -p "Voulez-vous effacer le contenu de ${target} (défaut: non) ? (oO/nN): " -t 30 choix  
        [ -z ${choix} ] && choix=n
        case $choix in
            o|O) if [[ $(find -H ${target} -maxdepth 0 -type d -empty) ]]
                 then
                    _say d "Répertoire ${target} vide"
                    return 0
                else
                    _say i "Nettoyage de ${target}"   
                    rm ${SCRIPT_HOME%/}/${target}/*
                    return 0
                fi
                ;;
                 
            n|N) _say k "Annulation du nettoyage de ${target}"; exit 1;;
              *) _say k "Choix invalide"; exit 1;;
        esac 
    done
}

_push_to_repository () {

    for source in $(ls ${SCRIPT_LIBS})
    do
        #_say d "librairie: $i"
        if _check_pylib_in_repo ${REPO_PACKAGE} $source
        then
            _say i "La librairie [${YELLOW}${source}${RESET}] déjà existante dans ${REPO_PYPI}"
            continue
        else
            _say i "Téléversement de $source dans ${REPO_URL}"
            $BIN_VENV_TWINE upload --repository-url $REPO_PYPI -u ${SERVER_USERNAME} --password ${SERVER_PASSWORD} ${SCRIPT_LIBS%/}/$source
        fi

    done
    
}


#Main

_check_apt_dependencies "python3" "python3-pip" "python3-venv"

_check_virtualenv

_check_python_dependencies "twine"

_check_directories "drop" "libs"

_clear_dest "libs"

_check_reachable_url ${REPO_URL} 

_untar_archive 

_push_to_repository

