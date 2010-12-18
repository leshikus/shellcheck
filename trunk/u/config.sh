#!/bin/sh

# Environment functions
function error() {
  echo "$1"
  exit 1
}

function get_timestamp() {
  date '+%d%H%M%S'
}

function quote_space() {
  sed -e 's/ /\\ /g'
}

#   Working directories
# DDIR this file script location
# QDIR the quoted version of DDIR
#
DDIR=`cd "$DDIR"; pwd -P`
QDIR=`echo "$DDIR" | quote_space`
mkdir -p "$DDIR"/dist "$DDIR"/timestamp "$DDIR"/tmp "$DDIR"/usr/bin

# Checking DDIR is set by the caller
ERR_MESSAGE="You should set DDIR variable before calling DDIR/config.sh or DDIR/util.sh"
fgrep "$ERR_MESSAGE" "$DDIR"/config.sh || error "$ERR_MESSAGE"

# Run an upper level config if any
USER=${USER:-hudson}
if test -f "$DDIR"/../config.sh
then
  . "$DDIR"/../config.sh
fi
  
# Software URL Bases
GNU_URL=${GNU_URL:-http://mirrors.kernel.org/gnu}

# Calculated varaibles
SSH_ID=${SSH_ID:-$USER@$SSH_SERVER}
SSH_PORT=${SSH_PORT:-22}

ARCH=`arch`
if test "$ARCH" = i686
then
  ARCH_BITS=32
elif test "$ARCH" = x86_64
then
  ARCH_BITS=64 
fi

# Setting PATH so installed tools have a priority
test "$CLEAN_ENV" = true || exec env -i CLEAN_ENV=true \
  USER=$USER \
  HOME=${HOME:-/home/hudson} \
  LANG='' \
  PATH="$DDIR/usr/bin:$DDIR/bin:/bin:/usr/bin" \
  LDFLAGS="-L$QDIR/usr/lib" \
  CPPFLAGS="-I$QDIR/usr/include" \
  LD_LIBRARY_PATH="$DDIR/usr/lib" \
  SVN_SSH="ssh -p $SSH_PORT" \
  SIMULATOR=${SIMULATOR} \
  TARGET_CC=${TARGET_CC} \
  SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
  SSH_AGENT_PID="$SSH_AGENT_PID" \
  sh -evx "$0" "$@"

