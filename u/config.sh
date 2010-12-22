#!/bin/sh

# Software URL Bases
GNU_URL=${GNU_URL:-http://mirrors.kernel.org/gnu}

# Detect errors
set -e

#   Working directories
# DDIR this file script location
# QDIR the quoted version of DDIR
#
DDIR=`cd "$DDIR"; pwd -P`
. "$DDIR"/util.sh

QDIR=`echo "$DDIR" | quote_space`
JOB=${JOB:-`basename "$0" .sh`}
TIMESTAMP=`get_timestamp`
RESULT_DIR="${RESULT_DIR:-$DDIR/result/${JOB}_$TIMESTAMP}"
LOG="$RESULT_DIR/${JOB}_$TIMESTAMP.log"
mkdir -p "$DDIR"/dist "$DDIR"/timestamp "$DDIR"/tmp "$DDIR"/usr/bin "$RESULT_DIR"

# Checking DDIR is set by the caller
ERR_MESSAGE="You should set DDIR variable before calling DDIR/config.sh or DDIR/util.sh"
fgrep "$ERR_MESSAGE" "$DDIR"/config.sh || error "$ERR_MESSAGE"

# Run an upper level config if any
USER=${USER:-hudson}
CONFIG='SIMULATOR TARGET_CC TARGET_AS TARGET_LD JOB RESULT_DIR'

if test -f "$DDIR"/../config.sh
then
  . "$DDIR"/../config.sh
fi
  
# Calculated varaibles
SSH_ID=${SSH_ID:-$USER@$SSH_SERVER}
SSH_PORT=${SSH_PORT:-22}

echo '+++ System'
uname -a
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
  SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
  SSH_AGENT_PID="$SSH_AGENT_PID" \
  `pass_env $CONFIG` \
  sh -e$- "$0" "$@" 2>&1 | tee "$LOG"

