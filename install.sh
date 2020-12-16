#!/bin/bash

# params
#   cli configuration
DIR=
PLATFORM=
PROFILE=
DEBUG=
#   parsing utilities
TMPDIR=$(mktemp -d -t sh-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)
platformfile="platforms"
profilefile="profiles"
setupfile="setup"
#   platform information
platformname=
defaultinstallcmd=
#   profile information
randomdefault=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
chosendirs=
chosenapps=

# log
padding="    "
logdepth=0
log() {
    tmp=$2
    for (( depth=0; depth < $logdepth; depth++ )); do
        tmp="$padding$tmp"
    done
    echo "[$1] $tmp"
}

incrdepth() {
    logdepth=$((logdepth + 1))
}
decrdepth() {
    logdepth=$((logdepth - 1))
}

info() {
    log "INFO " "$@"
}

warn() {
    log "WARN " "$@"
}

error() {
    log "ERROR" "$@"
}

debug() {
    if [ ${DEBUG:+1} ]; then
        log "DEBUG" "$@"
    fi
}

print_help() {
    echo "setup-helper: parser for config files to set up development environment"
    echo "Usage: ./install.sh [OPTIONS]"
    echo "OPTIONS:"
    echo "  --dir=DIR"
    echo "      (required) config files are contained in the dir folder"
    echo "  --platform=ARG"
    echo "      (required) parses config for platform ARG"
    echo "  --profile=ARG"
    echo "      parses config with profile ARG"
    echo "  --debug=x"
    echo "      enable debug logs"
}

# substitution values
bssub=${TMPDIR: -32}
bsdqsub=randomdefault

# file io utilities
scriptfilehandle=
set_script_file_handle() {
    scriptfilehandle="$TMPDIR/$1.sh"
}

write_to_script_file() {
    # replace subs with actual values
    tmp="${1//$bssub/\\}"
    tmp="${tmp//$bsdqsub/\"}"
    # if override flag is provided
    if [ $# -eq 2 ]; then
        echo "$tmp" > "$scriptfilehandle"
    else
        echo "$tmp" >> "$scriptfilehandle"
    fi
}

configfilehandle=
set_config_file_handle() {
    configfilehandle="$DIR/$1.conf"
}

configexists=
check_config_file() {
    incrdepth
    if [ ! -f "$configfilehandle" ]; then
        # if fatal flag is set
        if [ $# -eq 1 ]; then
            error "missing config file $configfilehandle"
            exit -1
        else
            info "file not found but not required $configfilehandle"
            configexists=0
        fi
    else
        configexists=1
    fi
    decrdepth
}

linenumber=
process_config_file() {
    linenumber=1
    OIFS=$IFS
    while IFS= read -r line
    do
        parse_line "$line"
        process_line_data
    done < $configfilehandle
    IFS=$OIFS
}

# state transition logic
qcurr=
qfin=

linenumber=
istag=
tagname=
isvalue=
rowvalues=
iskeyword=
currkeyword=
parse_line() {
    debug "parse line $linenumber"
    incrdepth
    OIFS=$IFS
    istag=0
    isvalue=0
    case $1 in
        *\[*\])
            istag=1
            tmp="${1#*\[}"
            tagname="${tmp%\]*}"
            debug "tagname $tagname"
            ;;
        *\"*)
            isvalue=1
            rowvalues=()
            debug "row values $1"
            tmp="${1//\\\"/$bsdqsub}"
            tmp="${tmp//\\/$bssub}"
            IFS='\"'
            read -ra split <<< "$tmp"
            skip=1
            for i in "${split[@]}"; do
                if [ $skip -eq 1 ]; then
                    skip=0
                else
                    skip=1
                    rowvalues+=("$i")
                    debug "extracted row value $i"
                fi
            done
            ;;
        *:)
            iskeyword=1
            tmp="${1// }"
            currkeyword="${tmp%\:*}"
            debug "found keyword $currkeyword"
            ;;
        "")
            ;;
        *)
            error "unrecognized pattern on line $linenumber: $1"
            exit -1
            ;;
    esac
    linenumber=$((linenumber + 1))
    IFS=$OIFS
    decrdepth
}

process_line_data() {
    debug "process line $linenumber"
    incrdepth
    if [ $istag -eq 1 ]; then
        case $qcurr in
            *)
                debug "default case for tag $tagname"
                ;;
        esac
    elif [ $iskeyword -eq 1 ]; then
        debug "keyword for state transition $currkeyword"
    elif [ $isvalue -eq 1 ]; then
        for value in "${rowvalues[@]}"; do
            case $qcurr in
                *)
                    debug "default case for value $value"
                    ;;
            esac
        done
    fi
    decrdepth
}

# path logic
isinhome=
isinroot=
pathcache=
check_path() {
    incrdepth
    isinhome=0
    isinroot=0
    case "$1" in
        $HOME/*)
            isinhome=1
            pathcache=$1
            ;;
        \~/*)
            isinhome=1
            pathcache="$HOME/${1##\~/}"
            ;;
        /*)
            isinroot=1
            pathcache=$1
            ;;
        *)
            ;;
    esac
    if [ $isinhome -eq 0 ] && [ $isinroot -eq 0 ]; then
        error "invalid path $1"
        info "please use absolute or home-relative paths"
        exit -1
    fi
    debug "isinhome: $isinhome isinroot: $isinroot for $1"
    debug "$1 was normalized to $pathcache"
    decrdepth
}

parse_platforms() {
    incrdepth
    info "parsing platforms"
    set_config_file_handle $platformfile
    check_config_file "x"
    process_config_file
    decrdepth
}

parse_profiles() {
    incrdepth
    info "parsing profiles"
    set_config_file_handle $profilefile
    check_config_file

    if [ $configexists -eq 1 ]; then
        process_config_file
    fi
    decrdepth
}

parse_setup() {
    incrdepth
    info "parsing directories"
    set_config_file_handle $setupfile
    check_config_file "x"
    set_script_file_handle $setupfile
    process_config_file
    decrdepth
}

# init arguments
for arg in "$@"; do
    IFS='='
    read -ra split <<< "$arg"
    case "${split[0]}" in
        "--help")
            print_help
            exit
            ;;
        "--dir")
            DIR="${split[1]}"
            ;;
        "--debug")
            DEBUG="x"
            ;;
        "--profile")
            PROFILE="${split[1]}"
            ;;
        "--platform")
            PLATFORM="${split[1]}"
            ;;
        *)
            error "unknow option ${split[0]}"
            print_help
            exit -1
            ;;
    esac
done

debug "debug mode enabled"
info "parsing for platform $PLATFORM"
if [ ${PROFILE:+1} ]; then
    info "using profile $PROFILE"
else
    PROFILE=randomdefault
    debug "using default profile $randomdefault"
fi
info "searching for config in $DIR"
info "writing temporary scripts to $TMPDIR"

# parsing config files
info "parse config start"

parse_platforms
parse_profiles
parse_setup

info "parse config end"

run_script() {
    incrdepth
    set_script_file_handle $1
    if [ -f "$scriptfilehandle" ]; then
        /bin/bash $scriptfilehandle
    else
        warn "tried to run config which did not exist $scriptfilehandle"
    fi
    decrdepth
}

# running parsed config files
info "running config start"

run_script "$setupfile"

info "running config end"

rm -rf "$TMPDIR"

