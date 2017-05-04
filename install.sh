#!/bin/sh

DESKTOP_FILE=netindic.desktop
AUTOSTART_DIR="$HOME/.config/autostart/"
INSTALL=/usr/bin/install
SED=/bin/sed
CURRENT_DIR=$(pwd)
NETINDIC_EXEC="$CURRENT_DIR/netindic.rb"
NETINDIC_ICON="$CURRENT_DIR/wrench-8x.png"

# $1 file to copy
# $2 destination dir
copy_file() {
  [ ! -d "$2" ] && "$INSTALL" -d "$2"
  "$INSTALL" -m 644 "$1" "$2"
}

# $1 path to netindic.rb
# $2 desktop file to change
set_exec_correct_path() {
  "$SED" -i "s#^Exec=.*#Exec=$1#" "$2"
}

# $1 path to icon
# $2 desktop file to change
set_icon_correct_path() {
  "$SED" -i "s#^Icon=.*#Icon=$1#" "$2"
}

ask_confirmation() {
  echo "Confirm autostart of netindic on session start? (y/n) "
  read -r r
  case $r in
    y|Y) return 0;;
    *) return 1;;
  esac
}

#######################################
if ask_confirmation; then
  if ! copy_file "$DESKTOP_FILE" "$AUTOSTART_DIR"; then
    echo "cannot install desktop file to $AUTOSTART_DIR" >&2
    exit 1
  fi
  if ! set_exec_correct_path "$NETINDIC_EXEC" "$AUTOSTART_DIR/$DESKTOP_FILE"; then
    echo "cannot set correct 'Exec=' parameter into desktop file" >&2
    exit 1
  fi
  if ! set_icon_correct_path "$NETINDIC_ICON" "$AUTOSTART_DIR/$DESKTOP_FILE"; then
    echo "cannot set correct 'Icon=' parameter into desktop file" >&2
    exit 1
  fi
  echo "Done!"
else
  echo "Cancelled!"
fi
