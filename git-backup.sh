#!/bin/bash
cd $(dirname $0)

# TODO:
# - Validate that it's a git directory
# - Add a dryrun option
# - Get date in a non macos specific way

# Repo to be backed up
REPO='/Users/eric/Dropbox/Apps/boostnote-mobile'

# Minimum time before another commit is made
MINHOURS=24

# File to log attempts
LOGFILE='git-backup.log'


# Set path (for the gdate command)
PATH=/usr/local/mysql/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin

# cd to the repo and exit if fails
if [[ ! "$PWD" == "$REPO" ]]; then
    echo "Script directory does not match repo directory"
    exit
fi

# Check if the directory is actually a git repo
if ! (git status &> /dev/null) ; then
    echo "ERROR: $PWD is not a git repo."
    exit 1
fi

# Check if the logfile is in the .gitignore, and if not, ask to append
if ! grep -Fxq "$LOGFILE" ".gitignore"; then
    echo "The log file: $LOGFILE is not in the gitignore. It will be added."
    while true; do
        read -rp "Confirm (y/n): " yn
        case $yn in
            [Yy]* )
                # Add the formatted entry to th gitignore.
                printf "\n" >> .gitignore
                echo '# Added by git-backup.sh' >> .gitignore
                echo "$LOGFILE" >> .gitignore
                break;;
            * )
                echo "Quitting."; exit;;  # continue looping
        esac
    done
fi

chmod a+w "$LOGFILE"

# If the logfile isn't found, it's the first run, so suggest the cronjob
if [ ! -f $LOGFILE ]; then
    red="$(tput setaf 1)"
    green="$(tput setaf 2)"
    yellow="$(tput setaf 3)"
    reset="$(tput sgr0)"
    bold="$(tput bold)"

    fullpath=$PWD"/"$(basename $0)
    printf "\nSetting up backups for the first time. Here's the (hourly) Cronjob:\n"

    printf "\n"
    echo $bold $green '0 * * * *' $fullpath '>/dev/null 2>&1' $reset
    printf "\n"

    echo "Add it to the crontab with:$bold$yellow crontab -e $reset"
    echo -n "$red"; echo "Exiting. (Run again to trigger a backup) $reset"

    touch $LOGFILE  # Create the logfile as a flag
    exit
fi

# Calculate hours since last commit
now=$(gdate)
lastCommitUnix=$(git log -1 --format=%at)
nowUnix=$(gdate +%s)

let elapsedHours="($nowUnix - $lastCommitUnix) / 60 / 60"

function logstatus() {
    case $1 in
        0) echo "COMMITED: $now" >> $LOGFILE; return;;
        1) echo "MIN_TIME_NOT_REACHED: $now" >> $LOGFILE; return;;
        2) echo "NO_NEW_FILES: $now" >> $LOGFILE; return;;
    esac
}

if [[ $elapsedHours -ge $MINHOURS ]]; then
    message="Automated commit: $now"
    git add .
    git commit -m "$message"
    git push
    logstatus 0
else
    logstatus 1
fi
