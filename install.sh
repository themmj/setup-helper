#!/bin/bash

# params
#   cli configuration
DIR=
PLATFORM=
DEBUG=
#   parsing utilities
TMPDIR=$(mktemp -d -t sh-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)
platformfile="platforms"
setupfile="setup"
#   platform information
defaultinstallcmds=()
#   default random
randomdefault=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
workingdir=$(pwd)

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
    ctbw="${1//$bssub/\\}"
    ctbw="${ctbw//$bsdqsub/\"}"
    # if override flag is provided
    if [ $# -eq 2 ]; then
        echo "$ctbw" > "$scriptfilehandle"
    else
        echo "$ctbw" >> "$scriptfilehandle"
    fi
}

configfilehandle=
set_config_file_handle() {
    configfilehandle="$workingdir/$DIR/$1.conf"
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
    if [ $isinhome -eq 1 ] || [ $isinroot -eq 1 ]; then
        debug "$1 was normalized to $pathcache"
    fi
    debug "isinhome: $isinhome isinroot: $isinroot for $1"
    decrdepth
}

dirstack=
currdir=
pushdir() {
    currdir=${1%/}
    if [ $# -eq 2 ]; then
        dirstack="$currdir "
    else
        dirstack="$currdir $dirstack"
    fi
    write_to_script_file "mkdir -p $currdir"
    write_to_script_file "cd $currdir"
}
popdir() {
    dirstack=${dirstack#* }
    currdir=${dirstack%% *}
    write_to_script_file "cd $currdir"
}

# keywords
kwapps="apps"
kwcmd="cmd"
kwenv="env"
kwfiles="files"
kwpackages="packages"
kwpkginstall="pkginstall"
kwrepos="repos"
kwsubdirs="subdirs"

# line parsing
linenumber=
istag=
isroottag=
tagname=
isvalue=
rowvalues=
iskeyword=
currkeyword=
currplatform=
currenvfile=
parse_line() {
    debug "parse line $linenumber"
    incrdepth
    OIFS=$IFS
    istag=0
    iskeyword=0
    isvalue=0
    case $1 in
        \[*\])
            istag=1
            isroottag=1
            tmp="${1#*\[}"
            tagname="${tmp%\]*}"
            debug "roottagname $tagname"
            ;;
        *\[*\])
            istag=1
            isroottag=0
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
        *.)
            popdir
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

process_tag() {
    debug "processing tag $tagname roottag: $isroottag"
    check_path "$tagname"
    if [ $isroottag -eq 1 ]; then
        if [ $isinroot -eq 1 ] || [ $isinhome -eq 1 ]; then
            write_to_script_file "echo \"[INFO ] setting up directory $pathcache\""
            pushdir "$pathcache" "x"
        else
            info "found platform $tagname"
            currplatform="$tagname"
        fi
    else
        case "$currkeyword" in
            "$kwsubdirs")
                pushdir "$currdir/$tagname"
                ;;
            "$kwapps")
                write_to_script_file "echo \"[INFO ] installing app $tagname\""
                ;;
            *)
                error "unexpected tag $tagname on line $linenumber"
                ;;
        esac        
    fi
}

process_keyword(){
    debug "processing keyword $currkeyword"
    case "$currkeyword" in
        "$kwapps")
            ;;
        "$kwcmd")
            ;;
        "$kwenv")
            currenvfile="$currdir/.env"
            write_to_script_file "echo \"\" > \"$currenvfile\""
            ;;
        "$kwfiles")
            ;;
        "$kwpackages")
            ;;
        "$kwpkginstall")
            ;;
        "$kwrepos")
            ;;
        "$kwsubdirs")
            ;;
        *)
            error "unknown keyword $currkeyword on line $linenumber"
            exit -1
            ;;
    esac
}

process_rowvalues(){
    arg0="${rowvalues[0]}"
    arg1="${rowvalues[1]}"
    arg2="${rowvalues[2]}"
    case "$currkeyword" in
        "$kwapps")
            error "invalid use of direct arguments under keyword $currkeyword on line $linenumber"
            exit -1
            ;;
        "$kwcmd")
            if [ "$arg0" == "$PLATFORM" ]; then
                write_to_script_file "$arg1"
            fi
            ;;
        "$kwenv")
            info "env vals ${rowvalues[@]}"
            if [ ${#rowvalues[@]} -eq 3 ]; then
                write_to_script_file "echo \"case \\\":\${$arg0}:\\\" in\" >> $currenvfile"
                write_to_script_file "echo \"*:$arg1:*)\" >> $currenvfile"
                write_to_script_file "echo \";;\" >> $currenvfile"
                write_to_script_file "echo \"*)\" >> $currenvfile"
                if [ ${rowvalues[2]} == "append" ]; then
                    write_to_script_file "echo \"export $arg0=\\\"\$$arg0:$arg1\\\"\" >> $currenvfile"
                else
                    write_to_script_file "echo \"export $arg0=\\\"\$$arg1:$arg0\\\"\" >> $currenvfile"
                fi
                write_to_script_file "echo \"esac\" >> $currenvfile"
            else
                write_to_script_file "echo \"export $arg0=$arg1\" >> $currenvfile"
            fi
            ;;
        "$kwfiles")
            case "$arg1" in
                "copy")
                    write_to_script_file "cp -r $workingdir/$arg0 $currdir"
                    ;;
                "link")
                    write_to_script_file "ln -f $workingdir/$arg0 $currdir"
                    ;;
                *)
                    error "invalid file option $arg1 on line $linenumber"
                    exit -1
            esac
            ;;
        "$kwpackages")
            write_to_script_file "${defaultinstallcmds[$PLATFORM]} $arg1"
            ;;
        "$kwpkginstall")
            defaultinstallcmds["$currplatform"]="$arg0"
            ;;
        "$kwrepos")
            write_to_script_file "git clone $arg0 $arg1"
            ;;
        "$kwsubdirs")
            error "invalid use of direct arguments under keyword $currkeyword on line $linenumber"
            exit -1
            ;;
        *)
            error "unknown keyword $currkeyword on line $linenumber"
            exit -1
            ;;
    esac
}

process_line_data() {
    debug "process line $linenumber"
    incrdepth
    if [ $istag -eq 1 ]; then
        process_tag
    elif [ $iskeyword -eq 1 ]; then
        process_keyword
    elif [ $isvalue -eq 1 ]; then
        process_rowvalues
    fi
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

parse_setup() {
    incrdepth
    info "parsing directories"
    set_config_file_handle $setupfile
    check_config_file "x"
    set_script_file_handle $setupfile
    write_to_script_file "#!/bin/bash" "x"
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
info "searching for config in $DIR"
info "writing temporary scripts to $TMPDIR"

# parsing config files
info "parse config start"

parse_platforms
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
