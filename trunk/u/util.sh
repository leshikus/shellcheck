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

function get_timestamp() {
  date '+%y%m%d%H%M%S'
}

function quote_space() {
  sed -e 's/ /\\ /g'
}

function restart_clean_env() {
  test "$CLEAN_ENV" = true || {
    local log="$RESULT_DIR/$JOBSTAMP.log"

    set_tmp_file_name restart.sh
    {
      echo exec env -i CLEAN_ENV=true LANG= \\
      for e in $CONFIG
      do
        echo "  $e=\"\${$e}\" \\"
      done
      if tty >/dev/null
      then
        echo "  sh -e -c 'sh -e$- \"$0\" " "$@" " 2>&1 | tee \"$log\"'" 
      else
        echo "  sh -e$- '$0' " "$@" " 1>'$log' 2>&1"
      fi
    } >"$TMP_FILE"
    . "$TMP_FILE"
  }
}

#
# Filesystem
#
function make_working_directories() {
  # Check DDIR is set by the caller
  ERR_MESSAGE="You should set DDIR variable before calling DDIR/config.sh"
  fgrep "$ERR_MESSAGE" "$DDIR"/util.sh || error "$ERR_MESSAGE"

  # Set job identifiers
  JOB=${JOB:-`basename "$0" .sh`}
  TIMESTAMP=`get_timestamp`
  JOBSTAMP="${JOB}_$TIMESTAMP"

  # Define working directories
  QDIR=`echo "$DDIR" | quote_space`
  RESULT_DIR="${RESULT_DIR:-$DDIR/result/$JOBSTAMP}"
  TMP_DIR="${TMP_DIR:-$DDIR/tmp/$JOBSTAMP}"
  mkdir -p "$DDIR"/dist "$DDIR"/timestamp "$DDIR"/usr/bin "$RESULT_DIR" "$TMP_DIR"
}

function get_script_dir() {
  readlink -f `dirname "$0"`
}

function set_tmp_file_name() {
  TMP_FILE="$DDIR/tmp/$JOBSTAMP/$1"
}

function add_line() {
  grep -Fx "$1" "$2" || echo "$1" >>"$2"
}

function rm_subdir() {
  test -d "$DDIR/$1" || error "No such dir: $1"
  test -n "$1" || error "Empty subdir: \$1"
  test -n "$2" || error "Empty subdir: \$2"
  RDD="$DDIR/$1"/"$2"
  test -d "$RDD" || return 0 # no need to remove empty directory
  touch "$RDD" || error "No permission to modify: $RDD"
  rm -rf "$RDD"
}

function rm_svn_subdir() {
  test -n "$1" || error "Empty svn subdir: \$1"
  test -d "$1/.svn" || error "Non-svn subdir: $1"
  rm -rf "$1"
}

#
# Dependence Download & Build Utilities
#
function unpack_dist() {
  DIST="$DDIR/timestamp/$1"

  FILE_TYPE=`file -b "$DIST"`
  case "$FILE_TYPE" in
  bzip2\ compressed\ data*)
    tar -jtf "$DIST" | head -1
    tar -jxf "$DIST" -C "$DDIR"/dist
    ;;
  gzip\ compressed\ data*)
    tar -ztf "$DIST" | head -1
    tar -zxf "$DIST" -C "$DDIR"/dist
    ;;
  Bourne\ shell\ script\ text\ executable)
    ln -fs "$DIST" "$DDIR/usr/bin/$DIST_NAME"
    chmod u+x "$DDIR/usr/bin/$DIST_NAME"
    return 1;
    ;;
  *)
    return 1;
  esac
}

function build_dist() {
  DIST_DIR="$1"
  test -n "$DIST_DIR" || error "Empty DIST_DIR"
  (
    cd "$DDIR/dist/$DIST_DIR"
    test -f "configure" && ./configure -prefix="$DDIR"/usr
    test -f "Makefile" && {
      make
      make install prefix="$DDIR"/usr
    }
  )
}

function test_dist() {
  (
    cd "$DDIR/dist/$DIST_DIR"
    make check
  )
}

# 0 if the file was not downloaded
function wget_newer() {
  set_tmp_file_name wget_dist_err
  (
    cd "$DDIR"/timestamp
    wget -N "$1" 2>"$TMP_FILE"
  )
  
  fgrep "Server file no newer than local file" "$TMP_FILE"
}

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
    cd "$DDIR"/timestamp
    wget "$DIST"."$DIST_SIG"
    check_sig "$DIST_NAME" "$DIST_SIG"
  )

  if DIST_DIR=`unpack_dist "$DIST_NAME"`
  then
    build_dist "$DIST_DIR"
  fi
}

function gnuget_dist() {
  wget_newer "$GNU_URL/gnu-keyring.gpg" || {
    gpg --import "$DDIR"/timestamp/gnu-keyring.gpg
  }
  wget_dist "$GNU_URL/$1" sig
}

function get_git_dist_dir() {
  echo "$1" | perl -n -e '/(\w+).git$/ && print $1'
}

function git_dist() {
  GIT_DIST="$1"
  CHECK_DIST="$2"

  DIST_DIR=`get_git_dist_dir "$GIT_DIST"`
  (
    if test -d "$DDIR/dist/$DIST_DIR/.git"
    then
      cd "$DDIR/dist/$DIST_DIR"
      git checkout | grep '' || return 0 # no changes
      git checkout . # revert changes
      git clean -xdf # delete untracked and ignored files
    else
      cd "$DDIR/dist"
      rm_subdir dist "$DIST_DIR"
      git clone "$GIT_DIST"
    fi
    build_dist "$DIST_DIR"
    test_dist  "$DIST_DIR"
  )
}

function update_dist() {
  local DIST="$SSH_ID:$1"
  local DIST_NAME=`basename "$1"`

  rsync -lptDzve "$SVN_SSH" "$DIST" "$DDIR"/timestamp |
    fgrep "$DIST_NAME" || return 0

  rsync -rLptDzve "$SVN_SSH" "$DIST" "$DDIR"/dist
}

#
# Replace the installation script with the tool
#
function exec_tool() {
  NAME=`basename "$0"`
  LOC=`which "$NAME"`
  if test "$LOC" == "$DDIR/bin/$NAME"
  then
    error "Cannot install $NAME - try to reinstal it manually"
  fi
  exec "$LOC" "$@"
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
    bin="$DDIR/dist/$basedir"
  }
  PATH="$bin:$PATH"
  export PATH

  TOOL="$bin/$name"
}

function set_cc() {
  set_tool_path ${TARGET_CC:-$1}

  TARGET_CC="$TOOL"
  TARGET_AS=${TARGET_AS:-`echo "$TOOL" | sed -e 's/g\?cc$/as/'`}
  TARGET_LD=${TARGET_LD:-`echo "$TOOL" | sed -e 's/g\?cc$/ld/'`}
  export TARGET_CC TARGET_AS TARGET_LD
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
  test ! -s unexpected_fail.list
)

