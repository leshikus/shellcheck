#!/bin/sh

function load_functions() {
  . "$DDIR"/util.sh
  check_env
}

function get_timestamp() {
  date '+%y%m%d_%H%M%S'
}

function apply_to_env_config() {
  alias config_env_callback=$1
  local config_env="$DDIR"/config.env.sh
  test "$config_env" -nt "$DDIR"/config.sh ||
    perl -n -e '/^([A-Z_]+)="\${\1(?::-[^}]*)*}"$/ && print "config_env_callback $1\n"' "$DDIR"/config.sh >"$config_env"
  . "$config_env"
}

function set_job_env() {
  DDIR=`readlink -f "$DDIR"`
  SCRIPT=`readlink -f "$0"`
  SCRIPT_DIR=`dirname "$SCRIPT"`
  SCRIPT_DIR_NAME=`basename "$SCRIPT_DIR"`
  JOB=`basename "$0" .sh`

  test "$JOB" != buildtasks || JOB="$SCRIPT_DIR_NAME"
}

function restart_if_needed() {
  case $JOBSTAMP in
    ${JOB}_*) # set when restart, no need to restart
      return;
      ;;
    '') # not set
      ;;
    *)  # incorrect
      echo "JOBSTAMP=$JOBSTAMP does not meet JOB=$JOB name"
      # exit 1 FIXME  uncomment and delete the next line
      unset WORKSPACE_DIR RESULT_DIR
      ;;
  esac
  restart_clean_env "$@"
}

function add_config_env() {
  local val="echo \$$1"
  val=`eval $val`
  test -z "$val" || echo "  $1='$val' \\"
}

function restart_clean_env() {
  local jobstamp=${JOB}_`get_timestamp`
  RESULT_DIR="${RESULT_DIR:-$TMP_DIR/$USER/result/$jobstamp}"

  mkdir -p "$RESULT_DIR"
  TMP_DIR=`readlink -f "$TMP_DIR"`
  RESULT_DIR=`readlink -f "$RESULT_DIR"`

  local log="$RESULT_DIR/$jobstamp.log"
  local start="$RESULT_DIR/$JOB"
  {
    echo exec nice env -i JOBSTAMP=$jobstamp \\
    apply_to_env_config add_config_env
    echo "  sh -e -o pipefail -c 'sh -e$- \"$SCRIPT\" \"\$@\""" 2>&1 | tee \"$log\"'" ' start.sh "$@"'
  } >"$start".sh
  . "$start".sh
}

function run_upper_level_config() {
  test ! -f "$DDIR"/../config.sh || . "$DDIR"/../config.sh
}

function set_working_directories() {
  mkdir "$TMP_DIR"/rm
  mv `ls -1ct "$TMP_DIR"/* "$TMP_DIR"/*/* | sed '1,32d'` "$TMP_DIR"/rm 2>/dev/null || true
  rm_dir "$TMP_DIR"/rm

  TMP_JOB_DIR="$TMP_DIR/$USER/$JOBSTAMP"
  unset JOBSTAMP

  BUILD_DIR="$TMP_JOB_DIR"/build
  CUR_DIR=`pwd -P`
  CUR_DIR_NAME=`basename "$CUR_DIR"`

  HUDSON_HOME="$DDIR"/../hudson_home
  JDIR="$HUDSON_HOME/jobs/$JOB"

  if test -d "$JDIR"
  then relink_job_workspace $JOB
  else JDIR="$SCRIPT_DIR"
  fi

  WORKSPACE_DIR="${WORKSPACE_DIR:-$JDIR/workspace}"
  mkdir -p "$TMP_DIR"/dist "$TMP_DIR"/downloads "$TMP_DIR"/tools/bin "$BUILD_DIR" "$TMP_JOB_DIR" "$RESULT_DIR" "$WORKSPACE_DIR"
  WORKSPACE_DIR=`readlink -f "$WORKSPACE_DIR"`

  # removable
  chmod a+w "$TMP_DIR"/dist "$TMP_DIR"/downloads "$TMP_DIR"/tools "$BUILD_DIR" "$TMP_DIR/$USER" "$RESULT_DIR" "$WORKSPACE_DIR" || true
}

function set_tool_env() {
  LANG=

  PATH="$TMP_DIR/tools/bin:$DDIR/bin:/bin:/usr/bin"
  LD_LIBRARY_PATH="$TOOL_DIR/lib"

  local q_tool_dir=`echo "$DDIR" | quote_space`
  LDFLAGS="-L$q_tool_dir/lib"
  CPPFLAGS="-I$q_tool_dir/include"

  SSH_ID=${SSH_ID:-$USER@$SSH_SERVER}
  SVN_SSH="ssh -p $SSH_PORT"

  KEY_NAME="$HOME"/.ssh/id_rsa
  export PATH LANG CCFLAGS CPPFLAGS LDFLAGS LD_LIBRARY_PATH SVN_SSH
}

function set_arch_env() {
  uname -a
  ARCH=`arch`
  if test "$ARCH" = i686
  then
    ARCH_BITS=32
  elif test "$ARCH" = x86_64
  then
    ARCH_BITS=64
  fi
}

set -e -o pipefail
test -n "$JOB" || { # include guard
  set_job_env
  run_upper_level_config
  restart_if_needed "$@"
  load_functions
  set_arch_env
  set_tool_env
  set_working_directories
}

