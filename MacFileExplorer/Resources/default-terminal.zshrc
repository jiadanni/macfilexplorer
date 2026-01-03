# MacFileExplorer Terminal Configuration
# This file is used instead of ~/.zshrc for the app's built-in terminal
# Location: ~/Library/Application Support/MacFileExplorer/terminal/.zshrc
# Edit this file to customize your in-app terminal experience

# Basic prompt (simple, fast)
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '

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
