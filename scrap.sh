#!/bin/bash

# urlencode() and urldecode() code taken from: https://gist.github.com/cdown/1163649
function urlencode() {
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

function urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}


function fetch_dir_list() {
    echo "$1" | sed -n '/fileListing/,$p' | grep "filebrowser-new.php?d" | sed -n 's/\(.*\)href="\([^"]\+\)"\(.*\)/\2/p' | sort | uniq
}

function fetch_file_list() {
    echo "$1" | sed -n '/samples/,$p' | grep '<li><a href=' | sed 's/<li>/\n/g' | sed -n 's/\(.*\)href="\([^"]\+\)"\(.*\)/\2/p' | sed -n '/\(.*\)\.mp3$/p' | sort | uniq
}

function process_dir() {
    ENCODED_DIR=$(urldecode $1)
    echo "== processing $ENCODED_DIR"

    mkdir -p "${DOWNLOAD_PATH}/${ENCODED_DIR}"

    DIR_CONTENT=$(wget -qO- ${ROOT_DIR}?d=${1})
    TYPE_CHECK=$(echo "$DIR_CONTENT" | grep '<ul class="playlist samples">')
    
    if [ -z "$TYPE_CHECK" ]; 
    then 
        DIR_LIST=$(fetch_dir_list "$DIR_CONTENT")

        if [ -z "$DIR_LIST" ];
        then
            return;
        fi

        echo "$DIR_LIST" | while read line
        do
            process_dir $(echo "$line" | cut -c24-9999)
        done
    else
        FILE_LIST=$(fetch_file_list "$DIR_CONTENT")

        if [ -z "$FILE_LIST" ];
        then
            return;
        fi

        echo "$FILE_LIST" | while read line
        do
            echo $(basename "$line")
            wget -q -P "${DOWNLOAD_PATH}/${ENCODED_DIR}" "${ROOT_URL}${line}"
        done
    fi
}

DOWNLOAD_PATH="$(pwd)/root"
mkdir -p "$DOWNLOAD_PATH"

ROOT_URL="http://sampleswap.org"

ROOT_DIR="${ROOT_URL}/filebrowser-new.php"
ROOT_HTML=$(wget -qO- "$ROOT_DIR")
ROOT_LIST=$(fetch_dir_list "$ROOT_HTML")

echo "$ROOT_LIST" | while read line
do
    process_dir $(echo "$line" | cut -c24-9999)
done

echo 'Done.'

