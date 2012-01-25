#!/usr/bin/env bash

# Path of the database used to keep track of directory hit counters.
PRODUCTIVITY_DATABASE=~/.productivity/productivity.sqlite

# Period (in seconds) of inactivity which causes a certain directory to be
# removed from the database:
#   1 week = 60 seconds * 60 minutes * 24 hours * 7 days = 604800 
PRODUCTIVITY_INACTIVITY=604800


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

    echo ${query} | sqlite3 ${PRODUCTIVITY_DATABASE} | sed 's/|/	/'
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
    # Remove hits older than one week.
    query="delete
            from dircounts
            where path in (
                select path
                from dircounts
                where strftime('%s', 'now') - strftime('%s', time) > ${PRODUCTIVITY_INACTIVITY}
                group by path
                having count(*) > 1
                order by time desc
            );"
    echo ${query} | sqlite3 ${PRODUCTIVITY_DATABASE}
    ;;

list)
    kind=$2
    prod_used ${kind}
    ;;

prompt)
    kind=$2
    destination=$3

    if [ -z "${destination}" ]; then
        declare -A choices
        set a s d f j k l
        while read path; do
            choices[$1]=$path
            echo "$1 -> $path"
            shift
        done< <(prod_used ${kind} | sed 's/[0-9: \-]*//')

        read -p "? "
        destination="${choices[${REPLY:-' '}]}"
    fi
    if [ -n "${destination}" ]; then
        echo "${destination}" > ~/.lastdir
        cd "${destination}"
    fi
    ;;
esac
