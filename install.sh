#!/bin/bash

# params
#   cli configuration
DIR=
PLATFORM=
PROFILE=
DEBUG=
#   parsing utilities
TMPDIR=$(mktemp -d -t setup-helper-XXXXXXXXXX)
platformfile="platforms"
profilefile="profiles"
dirfile="dirs"
appfile="apps"
#   platform information
platformname=
defaultinstallcmd=
#   profile information
randomdefault=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
chosendirs=
chosenapps=

log() {
    echo "[$1] $2"
}

info() {
    log "INFO" "$@"
}

warn() {
    log "WARN" "$@"
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

# file io utilities
scriptfilehandle=
set_script_file_handle() {
    scriptfilehandle="$TMPDIR/$1.sh"
}

write_to_script_file() {
    # if override flag is provided
    if [ $# -eq 2 ]; then
        echo "$1" > "$scriptfilehandle"
    else
        echo "$1" >> "$scriptfilehandle"
    fi
}

configfilehandle=
set_config_file_handle() {
    configfilehandle="$DIR/$1.conf"
}

configexists=
check_config_file() {
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
}

istag=
tagname=
rowvalues=
parse_line() {
    # TODO
}

# path logic
isinhome=
isinroot=
pathcache=
check_path() {
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
}

parse_platforms() {
    info "parsing platforms"
    set_config_file_handle $platformfile
    check_config_file "x"

    # TODO
}

parse_profiles() {
    info "parsing profiles"
    set_config_file_handle $profilefile
    check_config_file

    if [ $configexists -eq 1 ]; then
        # TODO
    fi
}

parse_dirs() {
    info "parsing directories"
    set_config_file_handle $dirfile
    check_config_file "x"

    set_script_file_handle $dirfile

    # TODO
}

parse_apps() {
    info "parsing apps"
    set_config_file_handle $appfile
    check_config_file "x"

    set_script_file_handle $appfile

    # TODO
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
parse_dirs
parse_apps

info "parse config end"

run_script() {
    set_script_file_handle $1
    if [ -f "$scriptfilehandle" ]; then
        /bin/bash $scriptfilehandle
    else
        warn "tried to run config which did not exist $scriptfilehandle"
    fi
}

# running parsed config files
info "running configs start"

run_script "$dirfile"
run_script "$appfile"

info "running configs end"

rm -rf "$TMPDIR"

