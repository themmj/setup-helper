# setup-helper  

A small code generator and runner designed to replicate a formally defined development environment.  

## Table of contents  

- [0. Prerequisites](#0-prerequisites)
- [1. Configuration files](#1-configuration-files)
  * [1.1 Platforms](#11-platforms)
  * [1.2 Setup](#12-setup)
    + [1.2.1 Directories](#121-directories)
    + [1.2.2 Apps](#122-apps)
- [2. Execution](#2-execution)
- [3. Example](#3-example)
  * [3.1 Configuration files](#31-configuration-files)
  * [3.2 Execution](#32-execution)

## 0. Prerequisites

This script was designed to have a minimal amount of dependencies.  
| Dependency | Why?                                                                                                              |
| ---------- | ----------------------------------------------------------------------------------------------------------------- |
| `git`      | is needed to clone this repository and to clone repositories defined in the setup.                                |
| `bash`     | is used to execute the script as sh was too limited.                                                              |  
| `tr`       | is used to create a random byte sequence from `/dev/urandom`. Maybe this dependency can be removed in the future. |  

## 1. Configuration files  

The script expects two configuration files:  
* `platforms.conf`
* `setup.conf`  

Both files are written in the same format:  
| Syntax element                    | Meaning                                                               |  
| --------------------------------- | --------------------------------------------------------------------- |  
| `[tag]`                           | specifing variable data like a directory or app name                  |  
| `keyword:`                        | one of the various available keywords for the predecessing tag        |  
| `"variable" "amount of" "values"` | content based on the predecessing keyword                             |  
| `.`                               | to close a defined tag (see [example usage](#31-configuration-files)) |   

There can only be one syntax element per line, meaning there cannot be i.e. a tag and a keyword on the same line. See the [configuration examples](#31-configuration-files) showcasing the structure.

### 1.1 Platforms  

The platform configuration contains available platforms with their specific information.  
| Supported keyword | Meaning                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------ |
| `pkginstall`      | Values[0]: platform specific command to install packages                                                           |  

### 1.2 Setup  

The setup configuration contains the setup which should be replicated. It is based on a hierarchy of absolute directories containing repos, files, subdirectories and apps.  
Directories and apps are declared using tags. Please note that **every tag must be closed using a `.`**.

#### 1.2.1 Directories

The following content can be configured under a directory tag:  
| Supported keyword | Meaning                                                                                                                                                                                |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps`            | beginning of a section containing app tags and their respective keywords and values                                                                                                    | 
| `env`             | creates an `.env` file <br> Values[0]: environment variable name <br> Values[1]: value of environment variable <br> Values[2]: (optional) use `append` or `prepend` to add the value to the beginning or end of the environment variable, overwrites variable with value if not set <br> Notes: a `.env` file sources all `.env` files of its subdirectories so only the `.env` files of the root directories need to be added to a `rc` file | 
| `files`           | files to be copied or linked into the directory <br> Values[0]: relative path (to the path the script was started in) to actual file <br> Values[1]: use `copy` or `link` to perform the desired action | 
| `repos`           | repos to be cloned into the subdirectory <br> Values[0]: git link to clone the repo <br> Values[1]: (optional) alternative folder name <br> Notes: will not clone if it already exists | 
| `subdirs`         | beginning of a section containing tags of subdirectories and their respective configuration                                                                                            | 

#### 1.2.2 Apps

The following content can be configured under an app tag:  
| Supported keyword | Meaning                                                                                                                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `packages`        | packages which need to be installed depending on the platform <br> Values[0]: platform <br> Values[1]: packages which will be installed with selected platform specific install command | 
| `cmds`            | custom commands which are executed based on selected platform <br> Values[0]: platform <br> Values[1]: custom command to be executed <br> Notes: double quotes need to be escaped       | 

Note: Using `all` for the first value in a `packages` or `cmds` line causes it to be executed regardless of the selected platform. See the [example usage](#31-configuration-files) of this below. 

## 2. Execution  

After the configuration files are created the script can be run with the required options:  
* `--platform=PLATFORM` runs the configuration for the specified platform
* `--dir=CONFIGDIR` the directory containing the config files (relative to pwd)  

See the [example](#32-execution) usage below.

## 3. Example

This is a rather nonsensical example to showcase the syntax and capabilities.

### 3.1 Configuration files

Directory structure of the example:  
```
.
├── config
│   ├── platforms.conf
│   └── setup.conf
├── res
│   ├── linkfile
│   ├── textfile
│   └── vimrc
└── setup-helper
    └── install.sh
```  

With the following config file content

`platforms.conf`:  
```
[debian]
    pkginstall:
        "sudo apt install"
.
[osx]
    pkginstall:
        "brew install"
.
```  

`setup.conf`:  
```
[~/development/testfolder]
    repos:
        "git@github.com:themmj/setup-helper.git"
        "git@github.com:themmj/slack.git" "slack-api"
    env:
        "VAR1" "val1"
        "VAR1" "val2" "append"
        "VAR1" "val3" "prepend"
    files:
        "../res/textfile" "copy"
        "../res/linkfile" "link"
    apps:
        [cmake]
            packages:
                "all" "cmake"
        .
        [vim]
            packages:
                "osx" "vim"
                "debian" "libx11-dev python3-dev"
            cmds:
                "debian" "git clone https://github.com/vim/vim.git"
                "debian" "cd vim && installcmds && cd .."
        .
    subdirs:
        [subfolder]
            env:
                "VAR2" "val4"
            files:
                "../res/vimrc" "copy"
        .
.
```  

### 3.2 Execution

The previously described setup can be used like this:
```bash
$ pwd
~/personal-setup/setup-helper$ 

$ ./install.sh --platform=osx --dir=../config
```

The resulting environment has the following structure:  
```
~
├── development
│   └── testfolder
│       ├── .env
│       ├── linkfile
│       ├── setup-helper
│       │   └── ...
│       ├── slack-api
│       │   └── ...
│       ├── subfolder
│       │   ├── .env
│       │   └── vimrc
│       └── textfile
└── personal-setup
    ├── config
    │   ├── platforms.conf
    │   └── setup.conf
    ├── res
    │   ├── linkfile
    │   ├── textfile
    │   └── vimrc
    └── setup-helper
        └── install.sh
```  
Note that there is no `vim` directory because on OSX it can be installed using brew and will therefore not be cloned. 