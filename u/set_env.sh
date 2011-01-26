#!/bin/sh

function load_functions() {
  DDIR=`readlink -f "$DDIR"`
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
  SCRIPT=`readlink -f "$0"`
  JOB=`basename "$0" .sh`

  HUDSON_HOME="$DDIR/../hudson_home"
  if test "$JOB" = buildtasks
  then
    JDIR=`dirname "$SCRIPT"`
    JOB=`basename "$JDIR"`
  else
    JDIR="$HUDSON_HOME/jobs/$JOB"
  fi
}

function restart_if_needed() {
  case $JOBSTAMP in
    ${JOB}_*) # set when restart, no need to restart
      return;
      ;;
    '') # not set
      restart_clean_env "$@"
      ;;
    *)  # incorrect
      echo "JOBSTAMP=$JOBSTAMP does not meet JOB=$JOB name"
      # exit 1 FIXME  uncomment
      ;;
  esac
}

function add_config_env() {
  local val="echo \$$1"
  val=`eval $val`
  test -z "$val" || echo "  $1='$val' \\"
}

function restart_clean_env() {
  local jobstamp=${JOB}_`get_timestamp`
  RESULT_DIR=`readlink -f "${RESULT_DIR:-$DDIR/result/$jobstamp}"`
  WORKSPACE_DIR=`readlink -f "${WORKSPACE_DIR:-$JDIR/workspace}"`
  local log="$RESULT_DIR/$jobstamp.log"
  local start="$RESULT_DIR/$JOB"
  mkdir -p "$RESULT_DIR"

  {
    echo exec nice env -i JOBSTAMP=$jobstamp \\
    apply_to_env_config add_config_env
    echo "  sh -e -c 'sh -e$- \"$SCRIPT\" " "$@" " 2>&1 | tee \"$log\"'"
  } >"$start".sh
  . "$start".sh
}

function run_upper_level_config() {
  if test -f "$DDIR"/../config.sh
  then
    . "$DDIR"/../config.sh
  fi
}

function set_working_directories() {
  TMP_JOB_DIR="$TMP_DIR/$JOBSTAMP"
  BUILD_DIR="$TMP_JOB_DIR"/build

  mkdir -p "$DDIR"/dist "$DDIR"/timestamp "$DDIR"/usr/bin "$BUILD_DIR"
  relink_job_workspace $JOB
}

function set_tool_env() {
  PATH="$DDIR/usr/bin:$DDIR/bin:/bin:/usr/bin"
  LANG=

  QDIR=`echo "$DDIR" | quote_space`
  LDFLAGS="-L$QDIR/usr/lib"
  CPPFLAGS="-I$QDIR/usr/include"
  LD_LIBRARY_PATH="$DDIR/usr/lib"

  SSH_ID=${SSH_ID:-$USER@$SSH_SERVER}
  SVN_SSH="ssh -p $SSH_PORT"

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
  restart_if_needed "$@"
  run_upper_level_config
  load_functions
  set_arch_env
  set_tool_env
  set_working_directories
}

