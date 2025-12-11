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

readonly BIN_PYTHON3=$(command -v python3)
readonly BIN_TAR=$(command -v tar)
readonly BIN_CURL=$(command -v curl)

readonly PEER_PACKAGE=${SCRIPT_HOME}/.peer_package/

#Message

DATE=$(date +"%Y-%m-%d %H:%M")

readonly RED="\e[1;91m"
readonly BLUE="\e[1;34m"
readonly GREEN="\e[1;92m"
readonly YELLOW="\e[0;33m"
readonly RESET="\e[0m"

readonly INFO="[${BLUE}$DATE${RESET}] [${BLUE}INFO${RESET}]>"
readonly OK="[${BLUE}$DATE${RESET}] [${GREEN}OK${RESET}]>"
readonly KO="[${BLUE}$DATE${RESET}] [${RED}KO${RESET}]>"
readonly DEBUG="[${BLUE}$DATE${RESET}] [${YELLOW}DEBUG${RESET}]>"

source $SCRIPT_CONF

#Argument

always_yes=0 
if [ "$1" == "--yes" ]; then always_yes=1 ; fi


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
        _say i "Vérification de la présence du package $dependencie prérequis de l'outil $0"
        if ! sudo apt list --installed 2> /dev/null | grep "$dependencie\/"
        then
            _say d "Le package $dependencie n'est pas installé et est un prérequis de l'outil $0"
            _say i "Installation de $dependencie"
            if ! sudo apt install $dependencie -y  ; then _say k "Installation echouée pour le package $dependencie"; exit 1; fi
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
            _say o "${py3dep} est installé via PIP"
        else
            _say k "${py3dep} n'est pas installé"
            _say d "Installation de ${py3dep}"
            if $BIN_VENV_PIP install ${py3dep} ; then _say i "Installation de ${py3dep} réussi"; else _say k "Erreur lors du téléchargement de ${py3dep}" ; exit 1 ; fi           
        fi
    done

}

_check_virtualenv () {

    if [ ! -d ${SCRIPT_VENV} ]
    then
        _say k "Aucun environnement virtuel présent pour l'outil"
        _say d "Création d'un environnement virtuel pour l'outil"
        $BIN_PYTHON3 -m venv ${SCRIPT_VENV}
    else
        _say o "Un environnement virtuel est configuré dans [${GREEN}${SCRIPT_VENV}${RESET}]"
    fi

    if [[ -e $BIN_VENV_ACT && -e $BIN_VENV_PIP ]]
    then
        _say o "Les outils python3 de l'environnement virtuel sont présent."
    else
        _say k "Les outils python3 de l'environnement virtuel ne sont pas présent"
        _say k "Supprimer l'environnement virtuel (rm -rf ${SCRIPT_VENV}) puis relancer $0"
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
            _say o "Le répertoire $directory existe"
        fi
    done


}

_check_reachable_url () {
    local url=${1}

    code=$($BIN_CURL -s -w "%{http_code}" -o /dev/null $url)

    if [ $code -eq 200 ]
    then
        _say o "L'URL $url est joignable"
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
   

    code=$(curl -s -u ${SERVER_USERNAME}:${SERVER_PASSWORD} -w "%{http_code}" -o /dev/null ${repo_target%/}/${lib[name]}/${lib[version]}/$library)
    
    
    if [ "$code" -eq 200 ]; then return 0 ; else return 1; fi
    
}

_untar_archive () {

    local source=${1}
    local target=${2}
    local extention=${3}

    local destination=$(realpath -s ${target})

    for archive in $(find ${source} -maxdepth 1 -type f -name "*.${extention}")
    do
        _say i "Extraction de l'archive $archive dans $destination"
        $BIN_TAR -xaf ${archive} -C ${destination}
    done

}

_clear_dest () {
    local target=${1}
    while true
    do
        if [[ "$always_yes" -eq 0 ]]
        then

            read -p "Voulez-vous effacer le contenu de ${target} (défaut: non) ? (oO/nN): " -t 30 choix  
            [ -z ${choix} ] && choix=n
        else
            choix=o
        fi

        case $choix in
            o|O) if [[ $(find -H ${target} -maxdepth 0 -type d -empty) ]]
                 then
                    _say i "Répertoire ${target} vide"
                    return 0
                else
                    _say d "Nettoyage de ${target}"   
                    find ${SCRIPT_HOME%/}/${target}/ -type f -delete
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
        if _check_pylib_in_repo ${REPO_PACKAGE} $source
        then
            _say o "La librairie [${YELLOW}${source}${RESET}] déjà existante dans ${REPO_PYPI}"
            continue
        else
            _say i "Téléversement de $source dans ${REPO_URL}"
            $BIN_VENV_TWINE upload --repository-url $REPO_PYPI -u ${SERVER_USERNAME} --password ${SERVER_PASSWORD} ${SCRIPT_LIBS%/}/$source
        fi

    done
    
}

_install_peer_package () {

    local source=${1}

    _check_virtualenv

    for dir in $(ls $source)
    do 
        case $dir in
            apt) _say d "Installation forcé des dépendances apt de $0"
                 sudo dpkg -i ${source}/$dir/*.deb
            ;;
            python) _say d "Installation forcé des dépendances python de $0"
                    while read line
                    do
                        $BIN_VENV_PIP install --no-index --find=${source}/python/ $line
                    done < ${source}/python/list
            ;;
        esac
    done
}

#Main

if [ "$1" == "--force-install" ]; then _install_peer_package ${PEER_PACKAGE}; exit 0; fi

_check_apt_dependencies "python3" "python3-pip" "python3-venv" "findutils" "tar" "curl"

_check_virtualenv

_check_python_dependencies "twine"

_check_directories "drop" "libs" ".peer_package"

_clear_dest "libs"

_untar_archive ${SCRIPT_HOME} ${SCRIPT_HOME} tar.zst

_untar_archive ${SCRIPT_DROP} ${SCRIPT_LIBS} tar.zst

_check_reachable_url ${REPO_URL} 

_push_to_repository

