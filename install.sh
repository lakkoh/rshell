#!/bin/bash
#
# install.sh — установщик конфигурации zsh проекта rshell.
# Копирует шаблон zshrc.template в ~/.zshrc, подставляя путь к репозиторию.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

trap 'echo -e "${RED}❌ Прервано.${RESET}"; exit 1' INT
set -e

VERSION="1.0.0"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rshell"
PLUGIN_DIR="$DATA_DIR/plugins"
DEST="$HOME/.zshrc"
DEST_BAK="$HOME/.zshrc.bak"
MARKER="установлено rshell"

print_usage() {
  echo "rshell $VERSION — установщик конфигурации zsh"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --uninstall   Удалить установленный ~/.zshrc (и восстановить бекап)"
  echo "  --help        Показать эту справку"
  echo "  --version     Показать версию"
  echo
  echo "Репозиторий рекомендуется держать в $DATA_DIR"
  echo "(install.sh предложит скопировать его туда при необходимости)."
}

check_zsh() {
  if ! command -v zsh &>/dev/null; then
    echo -e "${RED}❌ zsh не установлен. Установите zsh: sudo apt install zsh (Debian/Ubuntu)${RESET}"
    exit 1
  fi
}

same_dir() {
  [ "$1" = "$2" ]
}

# Определяет каталог-источник: либо сам репозиторий, либо его копию в XDG.
resolve_source_dir() {
  local repo_real data_real
  repo_real="$(cd "$REPO_DIR" && pwd -P)"
  if [ -d "$DATA_DIR" ]; then
    data_real="$(cd "$DATA_DIR" && pwd -P)"
  else
    data_real="$DATA_DIR"
  fi

  if same_dir "$repo_real" "$data_real"; then
    SRC_DIR="$REPO_DIR"
    return
  fi

  echo -e "${YELLOW}  ⚠ Репозиторий не в рекомендованном месте.${RESET}"
  echo -e "     Сейчас:   $REPO_DIR"
  echo -e "     Ожидается: $DATA_DIR"
  echo -e "     ~/.zshrc и плагины по умолчанию используют XDG-расположение."
  read -r -p "     Скопировать репозиторий в $DATA_DIR? [y/N]: " confirm
  case "$confirm" in
    [Yy]*)
      mkdir -p "$DATA_DIR"
      cp -a "$REPO_DIR/." "$DATA_DIR/"
      SRC_DIR="$DATA_DIR"
      echo -e "${GREEN}  → Скопировано в $DATA_DIR${RESET}"
      ;;
    *)
      SRC_DIR="$REPO_DIR"
      echo -e "${YELLOW}  → Использую текущее расположение: $REPO_DIR${RESET}"
      ;;
  esac
}

install_zshrc() {
  local template="$SRC_DIR/zshrc.template"
  if [ ! -f "$template" ]; then
    echo -e "${RED}❌ Не найден шаблон $template${RESET}"
    exit 1
  fi

  if [ -e "$DEST" ] || [ -L "$DEST" ]; then
    if [ ! -e "$DEST_BAK" ]; then
      cp -P "$DEST" "$DEST_BAK" 2>/dev/null || cp "$DEST" "$DEST_BAK"
      echo -e "${GREEN}  → Бекап: $DEST_BAK${RESET}"
    else
      echo -e "${YELLOW}  → Бекап уже существует, сохраняю оригинал: $DEST_BAK${RESET}"
    fi
  fi

  sed "s|@RSHELL_DIR@|$SRC_DIR|g" "$template" > "$DEST"
  echo -e "${GREEN}  → Установлен $DEST${RESET}"
}

post_install() {
  echo
  echo -e "${GREEN}════════════════════════════════════════${RESET}"
  echo -e "${GREEN}  Установка завершена!${RESET}"
  echo -e "${GREEN}════════════════════════════════════════${RESET}"
  echo -e "  Плагины будут загружены в $PLUGIN_DIR при первом запуске zsh."

  if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo
    echo -e "${YELLOW}  ⚠ zsh не является вашей login shell.${RESET}"
    echo -e "     Чтобы сменить: chsh -s $(command -v zsh)"
  fi

  echo
  echo -e "  🔄 Перезапустите терминал или выполните: exec zsh"
}

do_install() {
  echo -e "${GREEN}==> Установка rshell...${RESET}"
  check_zsh
  resolve_source_dir
  install_zshrc
  post_install
}

is_our_zshrc() {
  [ -f "$DEST" ] && grep -q "$MARKER" "$DEST" 2>/dev/null
}

do_uninstall() {
  echo -e "${YELLOW}==> Удаление конфигурации rshell...${RESET}"

  if [ ! -e "$DEST" ] && [ ! -L "$DEST" ]; then
    echo -e "${YELLOW}  → $DEST отсутствует, нечего удалять.${RESET}"
  elif is_our_zshrc; then
    rm -f "$DEST"
    echo -e "${GREEN}  → Удалён $DEST${RESET}"
    if [ -f "$DEST_BAK" ]; then
      mv "$DEST_BAK" "$DEST"
      echo -e "${GREEN}  → Восстановлен из бекапа: $DEST${RESET}"
    fi
  else
    echo -e "${YELLOW}  ⚠ $DEST не похож на установленный rshell — не трогаю.${RESET}"
  fi

  echo -e "${YELLOW}  ℹ Плагины остались в $PLUGIN_DIR.${RESET}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall)  do_uninstall; exit 0 ;;
    --help|-h)    print_usage; exit 0 ;;
    --version|-v) echo "rshell $VERSION"; exit 0 ;;
    *)
      echo -e "${RED}❌ Неизвестная опция: $1${RESET}"
      print_usage
      exit 1
      ;;
  esac
  shift
done

do_install
