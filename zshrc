# ──────────────────────────────────────────────────────────────
#  zshrc — переносимая конфигурация zsh (проект rshell)
#
#  Подключается из хост-файла ~/.zshrc (см. zshrc.template, install.sh).
#
#  Лицензия: MIT (см. LICENSE).
#  Сторонний код и его авторы: см. NOTICE.
#
#  Оглавление:
#    [1] ENVIRONMENT     — переменные окружения
#    [2] OPTIONS         — опции оболочки
#    [3] KEYBINDS        — привязки клавиш
#    [4] COMPLETION      — дополнения (compinit)
#    [5] PROMPT          — приглашение
#    [6] PLUGIN MANAGER  — мини-загрузчик плагинов (zsh_unplugged)
#
#  Плагины НЕ объявляются здесь: их список и порядок задаются в ~/.zshrc
#  хост-файле (см. zshrc.template).
# ──────────────────────────────────────────────────────────────


# ── [1] ENVIRONMENT ──────────────────────────────────────────

export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

# Уникальность и порядок в $PATH и $fpath.
typeset -U path PATH
typeset -U fpath

[[ -d ~/.local/bin ]] && path+=(~/.local/bin)


# ── [2] OPTIONS ──────────────────────────────────────────────

setopt EXTENDED_HISTORY      # метка времени в истории
setopt SHARE_HISTORY         # общая история между сессиями
setopt INC_APPEND_HISTORY    # писать историю сразу
setopt HIST_IGNORE_ALL_DUPS  # не дублировать записи
setopt HIST_IGNORE_SPACE     # не писать команды с ведущим пробелом
setopt HIST_REDUCE_BLANKS    # убирать лишние пробелы
setopt HIST_VERIFY           # показывать команду перед выполнением

setopt INTERACTIVE_COMMENTS  # '#' — комментарий в интерактивной сессии
setopt NO_BEEP               # без звукового сигнала
setopt AUTO_CD               # ввод каталога = переход в него
setopt PROMPT_SUBST          # подстановка в приглашении


# ── [3] KEYBINDS ─────────────────────────────────────────────

bindkey -e

# Delete и перемещение по словам (через terminfo — надёжнее хардкода).
(( ${+terminfo[kdch1]} )) && bindkey "${terminfo[kdch1]}" delete-char
(( ${+terminfo[kLFT5]} )) && bindkey "${terminfo[kLFT5]}" backward-word
(( ${+terminfo[kRIT5]} )) && bindkey "${terminfo[kRIT5]}" forward-word

# История с поиском по уже введённому префиксу.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
(( ${+terminfo[kcuu1]} )) && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
(( ${+terminfo[kcud1]} )) && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search


# ── [4] COMPLETION ───────────────────────────────────────────

# compinit вызывается здесь. Если понадобятся плагины дополнений, которым
# нужен fpath ДО compinit (например, zsh-completions), вынесите эти строки
# в ~/.zshrc после их загрузки.
skip_global_compinit=1
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"


# ── [5] PROMPT ───────────────────────────────────────────────

# Цвета (по умолчанию — настройте под себя).
typeset -g C_RESET="%f"
typeset -g C_USER="%f"
typeset -g C_ROOT="%f"
typeset -g C_RARROWS="%F{green}"
typeset -g C_LARROWS="%F{yellow}"
typeset -g C_OPERATOR="%F{cyan}"
typeset -g C_OPERAND="%F{yellow}"
typeset -g C_ERROR="%F{red}"

autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats '%b'

# Определяем контейнер/chroot один раз при старте, без форков на каждый промпт.
# Переменная ПУСТА вне контейнера (проверки ниже используют -n).
typeset -g RVDSH_INSIDE_CHROOT=
if grep -qaE '/(docker|lxc|chroot)' /proc/1/environ 2>/dev/null; then
  RVDSH_INSIDE_CHROOT=1
fi

# Код возврата и признаки контекста — обновляются перед каждым промптом.
_get_env() {
  typeset -g LASTEXITCODE=$?
  typeset -g WITH_SUBSHELL=
  if [[ "$ZSH_SUBSHELL" -gt 0 || "$SHLVL" -gt 1 ]]; then
    WITH_SUBSHELL=1
  fi
}

# Стрелка: результат последней команды и контекст (ssh/sudo, root).
_get_arrow() {
  if [[ $LASTEXITCODE -eq 127 ]]; then                 # команда не найдена
    echo "${C_ERROR}?${C_RESET}"
  elif [[ $LASTEXITCODE -ne 0 ]]; then                 # ошибка выполнения
    echo "${C_ERROR}${LASTEXITCODE}!${C_RESET}"
  else
    local special=
    [[ -n "$SSH_CLIENT" || -n "$SUDO_USER" ]] && special=1
    if [[ $EUID -eq 0 ]]; then
      [[ -n "$special" ]] && echo "${C_LARROWS}<<${C_RESET}" || echo "${C_RARROWS}>>${C_RESET}"
    else
      [[ -n "$special" ]] && echo "${C_LARROWS}<${C_RESET}" || echo "${C_RARROWS}>${C_RESET}"
    fi
  fi
}

# Сегменты (объявления через " | "): host, chroot, subshell, venv/conda, ветка.
_get_extras() {
  local seg segs=() out=""

  [[ -n "$SSH_CLIENT" ]]          && segs+=("%m")                 # хост (только ssh)
  [[ -n "$RVDSH_INSIDE_CHROOT" ]] && segs+=("chroot")
  [[ -n "$WITH_SUBSHELL" ]]       && segs+=("subshell")
  [[ -n "$VIRTUAL_ENV" ]]         && segs+=("${VIRTUAL_ENV:t}")   # виртуальное окружение
  [[ -n "$CONDA_DEFAULT_ENV" ]]   && segs+=("${CONDA_DEFAULT_ENV}")
  vcs_info
  [[ -n "$vcs_info_msg_0_" ]]     && segs+=("${vcs_info_msg_0_}") # ветка

  for seg in "${segs[@]}"; do
    out+=" ${C_OPERATOR}|${C_RESET} ${C_OPERAND}${seg}${C_RESET}"
  done
  [[ -n "$out" ]] && echo "$out"
}

_get_prompt() {
  local extras=$(_get_extras)
  local arrow=$(_get_arrow)
  PROMPT="%n${extras} ${arrow} "
  RPROMPT="%~"
}

precmd_functions+=(_get_env _get_prompt)


# ── [6] PLUGIN MANAGER ───────────────────────────────────────

# Каталог плагинов (вне зависимости от расположения репозитория).
: "${ZPLUGINDIR:=${XDG_DATA_HOME:-$HOME/.local/share}/rshell/plugins}"

# ── zsh_unplugged (встроен как есть) ─────────────────────────
# https://github.com/mattmc3/zsh_unplugged
# Лицензия: Unlicense (public domain). Автор: Matt Coleman (mattmc3).
# См. NOTICE. Плагины клонируются в $ZPLUGINDIR при первом запуске.

##? Clone a plugin using its github repo and (optionally) commit sha,
##? identify its init file, source it, and add it to your fpath.
function plugin-load {
  local plugin repo commitsha plugdir initfile initfiles=() clone_args=()
  : ${ZPLUGINDIR:=${ZDOTDIR:-~/.config/zsh}/plugins}
  for plugin in $@; do
    repo="$plugin"
    clone_args=(--quiet --depth 1 --recursive --shallow-submodules)
    commitsha=""
    # Pin repo to a specific commit sha if provided
    if [[ "$plugin" == *'@'* ]]; then
      repo="${plugin%@*}"
      commitsha="${plugin#*@}"
      clone_args+=(--no-checkout)
    fi
    plugdir=$ZPLUGINDIR/${repo:t}
    initfile=$plugdir/${repo:t}.plugin.zsh
    if [[ ! -d $plugdir ]]; then
      echo "Cloning $repo..."
      git clone "${clone_args[@]}" https://github.com/$repo $plugdir
      if [[ -n "$commitsha" ]]; then
        git -C $plugdir fetch -q origin "$commitsha"
        git -C $plugdir checkout -q "$commitsha"
      fi
    fi
    if [[ ! -e $initfile ]]; then
      initfiles=($plugdir/*.{plugin.zsh,zsh-theme,zsh,sh}(N))
      (( $#initfiles )) || { echo >&2 "No init file found '$repo'." && continue }
      ln -sf $initfiles[1] $initfile
    fi
    fpath+=$plugdir
    (( $+functions[zsh-defer] )) && zsh-defer . $initfile || . $initfile
  done
}
