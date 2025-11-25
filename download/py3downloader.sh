#!/bin/bash

#Variable
readonly SCRIPT=$(realpath -s $0)
readonly SCRIPT_NAME=${0/%.*/}
readonly SCRIPT_HOME=${SCRIPT%/*}
readonly SCRIPT_CONF=${SCRIPT_HOME}/${SCRIPT_NAME}.conf
readonly SCRIPT_VENV=${SCRIPT_HOME}/.venv/


readonly REQUIREMENT_LIST=${SCRIPT_HOME}/list/
readonly REQUIREMENT_FILE=${REQUIREMENT_LIST%/}/*.list
readonly REQUIREMENT_DATA=${SCRIPT_HOME}/data/

readonly URL_TEST="https://www.debian-fr.org/"

readonly BIN_VENV_PIP=${SCRIPT_VENV%/}/bin/pip
readonly BIN_VENV_ACT=${SCRIPT_VENV%/}/bin/activate
readonly BIN_PYTHON3=/usr/bin/python3
readonly BIN_LS=/usr/bin/ls
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
 
_mk_project_repository () {
    local project_name=${1}
    export dest_dir_project=${REQUIREMENT_DATA%/}/$project_name/ 

    if [ -d $dest_dir_project ]
    then
        _say i "${dest_dir_project} existe déjà"
        _clear_dest $project_name
    else
        _say i "Création du répertoire de destination du projet ${project_name}"
        mkdir -p ${dest_dir_project}
    fi
}

_dl_library () {
    local library=${1}
    local destination=${2}

    _say o "Téléchargement de la librairie: [${RED}${library}${RESET}]"
    #echo '${BIN_VENV_PIP} download ${library} --dest ${destination}'
    ${BIN_VENV_PIP} download ${library} --dest ${destination}
}

_clear_dest () {
    local project_name=${1}
    while true
    do
        read -p "Voulez-vous supprimer les anciennes librairies du projet ${project_name} (défaut: non) ? (oO/nN): " -t 30 choix  
        [ -z ${choix} ] && choix=n
        case $choix in
            o|O) _say i "Suppression des anciennes librairies du projet." ${project_name}
                 rm ${REQUIREMENT_DATA%/}/${project_name}/*.whl; _check_content ${REQUIREMENT_DATA%/}/${project_name}; return 0;;
                 
            n|N) _say k "Le projet existe déjà dans ${REQUIREMENT_DATA%/}/${project_name}."; exit 1;;
              *) _say k "Choix invalide"; exit 1;;
        esac 
    done
}

_check_content () {
    local source=${1}
    
    nb_file=$( $BIN_LS -l $source | head -n1 | cut -d " " -f2 )

    if [ ${nb_file} == "0" ]
    then
        return 0
    else
        _say k "Le répertoire ${source}/ n'est pas vide\nListe des fichiers restants: "
        $BIN_LS -l ${source}
        echo ""
        _say k "Supprimer les fichiers manuellement avant de relancer $0"
        exit 1
    fi
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

_check_internet_conn () {
	
	if [[ $(${BIN_CURL} -s -o /dev/null -w "%{http_code}" ${URL_TEST}) -ne 200 ]]
	then
		_say k "Aucun connexion à internet"
		exit 1
	fi
}

#Check
_check_internet_conn
_check_apt_dependencies "python3" "python3-pip" "python3-venv"
_check_virtualenv


#Main
_say i "Activation de l'environnement virtuel" 
source ${BIN_VENV_ACT}

_say i "Purge du cache de python"
${BIN_VENV_PIP} cache purge

for project in ${REQUIREMENT_FILE}
do  
    project_file=$(basename "$project")
    _mk_project_repository ${project_file%.*}
    
    _say info "Téléchargement de la liste de librairie du projet ${project_file%.*}"
    while read lib 
    do
        _dl_library ${lib} $dest_dir_project
    done < ${SCRIPT_HOME}/list/${project_file}

done

_say i "Désactivation de l'environnement virtuel" 
deactivate

_say i "That's all Folks"
