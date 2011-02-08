#!/bin/sh

function load_functions() {
  . "$DDIR"/util.sh
  check_env
}

function get_timestamp() {
  date '+%y%m%d_%H%M%S'
}

function quote_args() {
  for arg in $@
  do
    echo $arg | sed -e "s/^/\\'/" -e "s/$/\\'/" -e "s/[']/\\'/g"
  done
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
  WORKSPACE_DIR="${WORKSPACE_DIR:-$JDIR/workspace}"

  mkdir -p "$RESULT_DIR" "$WORKSPACE_DIR"
  TMP_DIR=`readlink -f "$TMP_DIR"`
  RESULT_DIR=`readlink -f "$RESULT_DIR"`
  WORKSPACE_DIR=`readlink -f "$WORKSPACE_DIR"`

  local log="$RESULT_DIR/$jobstamp.log"
  local start="$RESULT_DIR/$JOB"
  {
    echo exec nice env -i JOBSTAMP=$jobstamp \\
    apply_to_env_config add_config_env
    echo "  sh -e -o pipefail -c 'sh -e$- \"$SCRIPT\" \"\$@\""" 2>&1 | tee \"$log\"'" `quote_args "$@"`
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
  TMP_JOB_DIR="$TMP_DIR/$USER/$JOBSTAMP"
  BUILD_DIR="$TMP_JOB_DIR"/build

  mkdir -p "$TMP_DIR"/dist "$TMP_DIR"/downloads "$TMP_DIR"/tools/bin "$BUILD_DIR" "$TMP_JOB_DIR"

  # removable
  chmod a+w "$TMP_DIR"/dist "$TMP_DIR"/downloads "$TMP_DIR"/tools "$BUILD_DIR" "$TMP_DIR/$USER" "$RESULT_DIR" "$WORKSPACE_DIR"

  relink_job_workspace $JOB
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

