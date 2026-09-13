bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[3~" delete-char
bindkey "^H" backward-kill-word
bindkey "^[[3;5~" kill-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word

HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
export PATH="$JAVA_HOME/bin:$PATH"

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source <(fzf --zsh)

fpath=(/usr/share/zsh/site-functions $fpath)
autoload -Uz compinit

eval "$(starship init zsh)"

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

alias usar-java-8='export JAVA_HOME="$HOME/.local/jvm/java-8-oracle-amd64"; export PATH="$JAVA_HOME/bin:$PATH"; java -version'

alias usar-java-11='export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"; export PATH="$JAVA_HOME/bin:$PATH"; java -version'
setopt interactive_comments
