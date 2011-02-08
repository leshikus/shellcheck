#!/bin/sh

#
# Debug
#
function stack_dump() {
  local counter=${#FUNCNAME[@]}
  echo Stack dump:
    
  while counter=`expr $counter - 1`
  do
    echo "$counter ${BASH_SOURCE[$counter]}: ${BASH_LINENO[$counter - 1]}: ${FUNCNAME[$counter]}"
  done
}

# Environment functions
function error() {
  stack_dump
  echo "$1"
  exit 1
}

function quote_space() {
  sed -e 's/ /\\ /g'
}

function get_root_dir() {
  sed -e 's/\/.*$//'
}

#
# Filesystem
#
function relink_job_workspace() {
  local job="$1"
  local local_workspace="$HUDSON_HOME/jobs/$job"/workspace
  local workspace_dir="$TMP_DIR/$job"_workspace

  if test -L "$local_workspace"
  then
    rm "$local_workspace"
  elif test -d "$local_workspace"
  then rm -rf "$local_workspace"
  fi

  ln -s "$workspace_dir" "$local_workspace"
  mkdir -p "$workspace_dir"
}

function check_env() {
  local err_message="You should set DDIR variable before calling DDIR/config.sh"
  fgrep -q "$err_message" "$DDIR"/util.sh || error "$err_message"
}

function test_dir() {
  local dir="$1"
  test -n "$1" || error "The directory is not set"
  echo "$dir" | grep -q '^/......' || error "$dir is relative or less than six letters"
  echo "/$dir" | grep -vqF '/.' || error "$dir has . inside"
  touch "$dir"/.permission_test || error "$dir has invalid permissions"
}

function add_line() {
  grep -Fx "$1" "$2" || echo "$1" >>"$2"
}

function rm_dir() {
  local dir="$1"

  test_dir "$1"
  rm -rf "$dir"
}

function rm_svn_subdir() {
  local dir=`cd $1; pwd -P`
  test -d "$dir/.svn" || error "Non-svn subdir: $1"
  rm_dir "$dir"
}

function clean_tmp() {
  local dir="${1:-$TMP_DIR}"

  test_dir "$dir"
  echo "$dir" | fgrep -q "$TMP_DIR" || error "Is not a temporary directory: $dir"
  find "$dir" -maxdepth 1 -atime 2 -exec rm -rf {} \;
}

function get_dir_lock() {
  local timeout=1
  local lock="${1:-$HOME}"/.lock
  while expr $timeout \< 2048
  do
    test -f "$lock" || {
      echo $$ >"$lock"
      return
    }
    local pid=`cat $lock`
    echo "Waiting for $lock (PID = $pid) for $timeout sec"
    sleep $timeout
    timeout=`expr $timeout + $timeout`
  done
}

function release_dir_lock() {
  rm "${1:-$HOME}"/.lock
}

#
# Dependence Download & Build Utilities
#
function unpack_dist() {
  DIST="$TMP_DIR/downloads/$1"

  FILE_TYPE=`file -b "$DIST"`
  case "$FILE_TYPE" in
  bzip2\ compressed\ data*)
    tar -vjxf "$DIST" -C "$TMP_DIR"/dist >"$TMP_JOB_DIR/$1".log
    ;;
  gzip\ compressed\ data*)
    tar -vzxf "$DIST" -C "$TMP_DIR"/dist >"$TMP_JOB_DIR/$1".log
    ;;
  Bourne\ shell\ script\ text\ executable)
    ln -fs "$DIST" "$TOOL_DIR/bin/$DIST_NAME"
    chmod u+x "$TOOL_DIR/bin/$DIST_NAME"
    return 1;
    ;;
  *)
    return 1;
  esac
  head -1 "$TMP_JOB_DIR/$1".log | get_root_dir
}

function build_dist() (
  DIST_DIR="$TMP_DIR/dist/$1"
  test_dir "$DIST_DIR"

  test -x "$DIST_DIR"/configure || {
    find "$DIST_DIR" -type f -perm /u+x -exec ln -fs {} "$TMP_DIR"/tools/bin \;
    return
  }

  cd "$BUILD_DIR"
  "$DIST_DIR"/configure --prefix="$TMP_DIR"/tools
  make
  make install
)

function test_dist() (
  cd "$TMP_DIR/dist/$DIST_DIR"
  make check
)

# 0 if the file was not downloaded
function wget_newer() (
  cd "$TMP_DIR"/downloads
  wget -N "$1" 2>"$TMP_JOB_DIR"/wget_dist_err
  fgrep -q "Server file no newer than local file" "$TMP_JOB_DIR"/wget_dist_err
)

function check_sig() {
  DIST_NAME="$1"
  DIST_SIG="$2"
  case "$DIST_SIG" in
    sig)
      gpg --verify "$DIST_NAME"."$DIST_SIG"
      ;;
  esac
}

function wget_dist() {
  DIST="$1"
  DIST_NAME=`basename "$DIST"`
  DIST_SIG="$2"

  if wget_newer "$DIST"
  then
    return 0
  fi

  test -z "$DIST_SIG" || (
    cd "$TMP_DIR"/downloads
    wget "$DIST"."$DIST_SIG"
    check_sig "$DIST_NAME" "$DIST_SIG"
  )

  DIST_DIR=`unpack_dist "$DIST_NAME"` || return
  build_dist "$DIST_DIR"
}

function get_gnu_dist() {
  wget_newer "$GNU_URL/gnu-keyring.gpg" ||
    gpg --import "$TMP_DIR"/downloads/gnu-keyring.gpg

  wget_dist "$GNU_URL/$1" sig
}

function get_dist() {
  local url="$1"

  case "$url" in
    http://*/gnu/*)
      get_gnu_dist "$url"
      break
      ;;
    http://*) 
      wget_dist "$url"
      break
      ;;
    git:*)
      get_git_dist "$url"
      break
      ;;
    *)
      error "Cannot get $url"
   esac
}

function get_git_dist_dir() {
  echo "$1" | perl -n -e '/(\w+).git$/ && print $1'
}

function get_git_dist() {
  GIT_DIST="$1"
  CHECK_DIST="$2"

  DIST_DIR=`get_git_dist_dir "$GIT_DIST"`
  (
    if test -d "$TMP_DIR/dist/$DIST_DIR/.git"
    then
      cd "$TMP_DIR/dist/$DIST_DIR"
      git checkout | grep '' || return 0 # no changes
      git checkout . # revert changes
      git clean -xdf # delete untracked and ignored files
    else
      cd "$TMP_DIR/dist"
      rm_dir "$TMP_DIR/dist/$DIST_DIR"
      git clone "$GIT_DIST"
    fi
    build_dist "$DIST_DIR"
    test_dist  "$DIST_DIR"
  )
}

function update_dist() {
  local DIST="$SSH_ID:$1"
  local DIST_NAME=`basename "$1"`

  rsync -lptDzve "$SVN_SSH" "$DIST" "$TMP_DIR"/downloads |
    fgrep "$DIST_NAME" || return 0

  rsync -rLptDzve "$SVN_SSH" "$DIST" "$TMP_DIR"/dist
}

#
# Setting environment
#
function set_tool_path() {
  TOOL="$1"
  local bin=`dirname "$TOOL"`
  local name=`basename "$TOOL"`
  test -x "$TOOL" || {
    ssh -p $SSH_PORT $SSH_ID "test -x '$TOOL'" ||
        error "The tool '$TOOL' cannot be found"
    local basedir=`basename "$bin"`
    if test "$basedir" = bin
    then
      bin=`dirname "$bin"`
      basedir=`basename "$bin"`/"$basedir"
    fi
    
    update_dist "$bin"
    bin="$TMP_DIR/dist/$basedir"
  }
  PATH="$bin:$PATH"
  export PATH

  TOOL="$bin/$name"
}

function set_cc() {
  set_tool_path ${TARGET_CC:-$1}

  TARGET_CC="$TOOL"
  CROSS_COMPILE=`echo "$TOOL" | sed -e 's/g\?cc$//'`
  TARGET_AS="${TARGET_AS:-${CROSS_COMPILE}as}"
  TARGET_LD="${TARGET_LD:-${CROSS_COMPILE}ld}"
  
  export CROSS_COMPILE TARGET_CC TARGET_AS TARGET_LD
}

function set_simulator() {
  set_tool_path ${SIMULATOR:-$1}
  SIMULATOR="$TOOL"
  export SIMULATOR
}

#
# Running tests
#
function add_script_env() {
  local var="$1"

  if fgrep -q "$1"
  then
    eval "echo $var=\\\${$var:-\$$var}"
  fi
}

function create_launch_scripts() {
  local test_dir="$1"
  local test_ext="$2"
  shift 2

  cat <<EOF
function pass() {
  echo "\$1" >>'$RESULT_DIR'/successful.list
}

function fail() {
  echo "\$1" >>'$RESULT_DIR'/failure.list
}

EOF
  
  find "$test_dir" -name "*$test_ext" "$@" | while read t
  do
    local test=`basename "$t" $test_ext` 
    local dir=`dirname "$t"`
    local launcher="$dir/test_$test.sh"
    local script=`get_script_source "$test"`

    cat <<EOF >"$launcher"
#!/bin/sh

set -e
`
echo $script | add_script_env TARGET_CC
echo $script | add_script_env TARGET_AS
echo $script | add_script_env TARGET_LD 
echo $script | add_script_env SIMULATOR`

cd '$dir'
$script
EOF
    echo "sh -e$- '$launcher' && pass '$t' || fail '$t'"
  done
}

function evaluate_log() (
  cd "$RESULT_DIR"

  get_exclude_list >expected_fail.list
  touch successful.list failure.list
  cat failure.list expected_fail.list expected_fail.list | sort | uniq -c |
    awk '{ if ($1 == 1) print $2 }' >unexpected_fail.list

  echo "Tests completed:"
  wc -l successful.list failure.list
  wc -l expected_fail.list unexpected_fail.list
  echo "Unexpected failures:"
  cat unexpected_fail.list
  test ! -s unexpected_fail.list
)

function create_and_run_tests() (
  cd "$WORKSPACE_DIR"/trunk
  create_launch_scripts "$@" >"$JDIR"/launch_scripts.sh
  . "$JDIR"/launch_scripts.sh
  evaluate_log
)

#
# Configure Hudson
# 
function hudson_hide_sensitive_data() {
  # Keep private keys safe
  local keydir="$HUDSON_HOME"/subversion-credentials
  mkdir -p "$keydir"
  chmod 700 "$keydir"
}

function hudson_relink_workspaces() {
  local job_dir
  for job_ws_dir in "$HUDSON_HOME"/jobs/*/config.xml
  do
    local job_dir=`dirname "$job_ws_dir"`
    local job=`basename "$job_dir"`
    relink_job_workspace "$job"
  done
}

function hudson_update_workspace() (
  cd "$JDIR"
  perl ../../../u/parse_hudson_config.pl <config.xml >svn_update.sh

  cd workspace
  . "$JDIR"/svn_update.sh
)

