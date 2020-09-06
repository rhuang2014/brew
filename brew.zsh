#!/usr/bin/env zsh
#
# zsh-brew
#
# version 1.0.0
# author: Roger huang
# url: https://github.com/rhuang/zsh-brew

(( $+commands[brew] )) || return
(( $+commands[pyenv] )) && alias brew='env PATH=${PATH//$(pyenv root)\/shims:/} brew'
if alias b &>/dev/null; then unalias b && alias b='brew'; else alias b='brew'; fi
export PATH="$(brew --prefix)/sbin:$PATH"
export HOMEBREW_EDITOR=vim
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS="--appdir=/Applications --fontdir=/Library/Fonts --require-sha"
# keep the key file encrypted and only export if it's unencrypted
typeset -g HOMEBREW_API_TOKEN_KEY
HOMEBREW_API_TOKEN_KEY=${HOMEBREW_API_TOKEN_KEY:-${HOME}/brew-api.key}
if [[ "$(file -b ${HOMEBREW_API_TOKEN_KEY} | awk '{print $1}')" == "ASCII" ]]; then
    export HOMEBREW_GITHUB_API_TOKEN=$(cat ${HOMEBREW_API_TOKEN_KEY})
fi
typeset -g CASKROOM_PATH="$(brew --prefix)/Caskroom"

__cask-upgrade() {
    (( ${#@} < 1 )) && return
    local caskBasePath=${CASKROOM_PATH}
    local currentVersion
    local cask="$1"
    local caskDirectory="${caskBasePath}/${cask}"
    [[ -n ${cask} ]] || return
    currentVersion=$(/bin/ls -t $caskDirectory | head -1)
    newVersion=$(brew cask info ${cask} | grep "^${cask}:" | awk '{print $2}')
    if [[ ${newVersion} != ${currentVersion} ]]; then
        brew cask install "${cask}"
    fi
}

__clean-cask() {
    local caskMetadata="${caskDirectory}/.metadata"
    [[ -d ${caskMetadata} ]] || return
    local caskBasePath=${CASKROOM_PATH}
    local cask="$1"
    local caskDirectory="${caskBasePath}/${cask}"
    local -a versionsToRemoves
    versionsToRemoves=("${(@f)$(/bin/ls -t $caskDirectory | sed '1,1d')}")
    if (( ${#versionsToRemoves} > 0 )); then
        for versionToRemove (${versionsToRemoves}); do
            echo "Removing ${cask} ${versionToRemove}..."
            rm -rfv "${caskDirectory}/${versionToRemove}"
            rm -rfv "${caskMetadata}/${versionToRemove}"
        done
    fi
}

cask-upgrade() {
    if (( ${#@} == 0 )); then
        while read cask; do
            __cask-upgrade "$cask"
        done <<< "$(brew list --cask)"
    else
        __cask-upgrade "$1"
    fi
}

cask-clean() {
    if (( ${#@} < 1 )); then
        while read cask; do
            __clean-cask "$cask"
        done <<< "$(brew list --cask)"
    else
        __clean-cask "$1"
    fi
}

brew-it() {
    brew update && brew upgrade 2>/dev//null && brew cleanup --prune=3 -s && brew services cleanup
    cask-upgrade
    cask-clean
    (brew missing 2>&1; PATH=${PATH//$(pyenv root)\/shims:/} brew doctor --verbose 2>&1; brew cask doctor 2>&1) | egrep -i '(error|warning):' | egrep -v 'macOS 10.10|Unknown support status'
    (( $? )) || echo "run 'brew missing', 'brew doctor --verbose' and 'brew cask doctor' for details"
}

brew-init() {
    PATH=${PATH//$(pyenv root)\/shims:/} brew doctor --verbose && brew fetch git tree vim zsh --deps && brew install git tree vim zsh --verbose
}
