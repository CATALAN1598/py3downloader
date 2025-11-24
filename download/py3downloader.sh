#!/bin/bash

#Varaible
readonly SCRIPT=$(realpath -s $0)
readonly SCRIPT_NAME=${0/%.*/}
readonly SCRIPT_HOME=${SCRIPT%/*}
readonly SCRIPT_CONF=${SCRIPT_HOME}/${SCRIPT_NAME}.conf
readonly SCRIPT_VENV=${SCRIPT_HOME}/.venv/


readonly REQUIRMENT_LIST=${SCRIPT_HOME}/list/
readonly REQUIRMENT_FILE=${REQUIRMENT_LIST%/}/*.list 
readonly REQUIRMENT_DATA=${SCRIPT_HOME}/data/


readonly BIN_VENV_PIP=${SCRIPT_VENV%/}/bin/pip
readonly BIN_VENV_ACT=${SCRIPT_VENV%/}/bin/activate

readonly BIN_LS=/usr/bin/ls

#Message
readonly RED="\e[1;91m"
readonly BLUE="\e[1;34m"
readonly GREEN="\e[1;92m"
readonly YELLOW="\e[30;103m"
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
 
_mk_project_repository () {
    local project_name=${1}
    export dest_dir_project=${REQUIRMENT_DATA%/}/$project_name/ 

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
    echo '${BIN_VENV_PIP} download ${library} --dest ${destination}'
}

_clear_dest () {
    local project_name=${1}
    while true
    do
        read -p "Voulez-vous supprimer les anciennes librairies du projet ${project_name} (défaut: non) ? (oO/nN): " -t 30 choix  
        [ -z ${choix} ] && choix=n
        case $choix in
            o|O) _say i "Suppression des anciennes librairies du projet" ${project_name}
                 rm ${REQUIRMENT_DATA%/}/${project_name}/*.whl; _check_content ${REQUIRMENT_DATA%/}/${project_name}; return 0;;
                 
            n|N) _say k "Le projet existe déjà dans $0"; exit 1;;
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

#Main
_say i "Activation de l'environnement virtuel" 
source ${BIN_VENV_ACT}

_say i "Purge du cache de python"
$BIN_VENV_PIP cache purge

for project in $(ls $REQUIRMENT_LIST)
do  
    
    _mk_project_repository ${project/%.*/}
    
    _say info "Téléchargement de la liste de librairie du projet" ${projet/%.*/}
    while read lib 
    do
        _dl_library ${lib} $dest_dir_project
    done < ${SCRIPT_HOME}/list/$project

done

_say i "Désactivation de l'environnement virtuel" 
deactivate

_say i "That's all Folks"
