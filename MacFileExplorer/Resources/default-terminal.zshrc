# MacFileExplorer Terminal Configuration
# This file is used instead of ~/.zshrc for the app's built-in terminal
# Location: ~/Library/Application Support/MacFileExplorer/terminal/.zshrc
# Edit this file to customize your in-app terminal experience

# Shell integration (OSC 133 semantic prompts). The app's terminal parses these
# markers to know exactly where each prompt, command, and its output begin/end:
#   A = fresh line / prompt start   B = prompt end (user input starts here)
#   C = command execution start     D;<exit> = command finished, with exit code
function mfe_precmd() {
    local exit_code=$?
    # Close the previous command's output region (skip the very first prompt).
    if [[ -n "$MFE_CMD_ACTIVE" ]]; then
        printf '\033]133;D;%s\007' "$exit_code"
        unset MFE_CMD_ACTIVE
    fi
    printf '\033]133;A\007'
}
function mfe_preexec() {
    printf '\033]133;C\007'
    MFE_CMD_ACTIVE=1
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd mfe_precmd
add-zsh-hook preexec mfe_preexec

# Basic prompt (simple, fast). The trailing OSC 133;B marks the end of the
# prompt string, i.e. the exact column where the user's typed input begins.
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ %{$(printf "\033]133;B\007")%}'

# Common aliases
alias python="python3"
alias pip="pip3"
alias vi="vim"
alias ll="ls -la"
alias la="ls -A"

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt SHARE_HISTORY

# PATH is inherited from parent process - add extras here if needed
