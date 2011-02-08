#!/bin/sh

DDIR=`dirname "$0"`/..
. "$DDIR"/config.sh

#
# Replace the installation script with the tool
#
function try_exec_tool() {
  NAME=`basename "$0"`
  LOC=`which "$NAME"`
  test "$LOC" != "$DDIR/bin/$NAME" # then return 1
}

get_dir_lock "$TMP_DIR"/tools

try_exec_tool "$@" || {
  get_dist_callback
  try_exec_tool "$@" || {
    release_dir_lock "$TMP_DIR"/tools
    error "Cannot install $0 - try to reinstall it manually"
  }
}

release_dir_lock "$TMP_DIR"/tools
exec "$LOC" "$@"

