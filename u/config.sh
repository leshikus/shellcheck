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
HOME=${HOME:-/home/hudson}
LANG=

# Allowed environment, other vars are reset
CONFIG='
USER
HOME
LANG
SIMULATOR
TARGET_CC
TARGET_AS
TARGET_LD
JOB
RESULT_DIR
SVN_SSH
SSH_AUTH_SOCK
SSH_AGENT_PID'

if test -f "$DDIR"/../config.sh
then
  . "$DDIR"/../config.sh
fi
  
# Calculated varaibles
SSH_ID=${SSH_ID:-$USER@$SSH_SERVER}
SSH_PORT=${SSH_PORT:-22}
SVN_SSH="ssh -p $SSH_PORT"

uname -a # System
ARCH=`arch`
if test "$ARCH" = i686
then
  ARCH_BITS=32
elif test "$ARCH" = x86_64
then
  ARCH_BITS=64 
fi

restart_clean_env "$@"

