#!/usr/bin/env bash

# Path of the database used to keep track of directory hit counters.
PRODUCTIVITY_DATABASE=~/.productivity/productivity.sqlite


function prod_used() {
    local kind

    kind=${1}
    if [ "${kind}" = 'frequently' ]; then
        query="select count(*), path
                from dircounts
                group by path
                order by count(*) desc
                limit 7;"
    elif [ "${kind}" = 'recently' ]; then
        query="select time, path
                from dircounts
                group by path
                order by time desc
                limit 7;"
    fi

    echo ${query} | sqlite3 ${PRODUCTIVITY_DATABASE} | sed 's/|/\t/'
}


# entry point
case "$1" in
init)
    # Create and initialize the database containing the table needed to keep track
    # of directories hit counters.
    mkdir -p ~/.productivity

    # If the database has already been created, ask for conditional dump.
    if [ -f "${PRODUCTIVITY_DATABASE}" ]; then
        read -p "Database already created: dump it? [y/N] "
        if [ "${REPLY}" = "y" ]; then
            rm "${PRODUCTIVITY_DATABASE}"
        fi
    fi

    query="CREATE TABLE dircounts (
        path VARCHAR(255) NOT null,
        time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"
    echo ${query} | sqlite3 ${PRODUCTIVITY_DATABASE}
    ;;

update)
    # Update the counter associated the current directory if the currect
    # directory is different from the previous ine.
    current="$2"
    query="INSERT into dircounts(path) VALUES('${current}');"
    echo ${query} | sqlite3 ${PRODUCTIVITY_DATABASE}
    ;;

damp)
    # Remove directory hits older than one week.
    echo "Not yet implemented"
    ;;

list)
    kind=$2
    prod_used ${kind}
    ;;

prompt)
    kind=$2

    declare -A choices
    set a s d f j k l
    while read path; do
        choices[$1]=$path
        echo "$1 -> $path"
        shift
    done< <(prod_used ${kind} | sed 's/[0-9: \-]*//')

    read -p "? "
    destination="${choices[${REPLY:-' '}]}"
    if [ -n "${destination}" ]; then
        echo "${destination}" > ~/.lastdir
        bash --login
    fi
    ;;
esac
