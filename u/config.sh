#!/bin/sh

#
# Software URL Bases
#
GNU_URL=${GNU_URL:-http://mirrors.kernel.org/gnu}

#
# Detect errors
#
set -e

#
# Load functions
#
DDIR=`cd "$DDIR"; pwd -P`
. "$DDIR"/util.sh

make_working_directories

#
# Set user environment
#
USER=${USER:-hudson}
HOME=${HOME:-/home/hudson}
LANG=

#
# Allowed environment, other vars are reset
#
CONFIG='
USER
HOME
PATH
CCFLAGS
CPPFLAGS
LDFLAGS
LD_LIBRARY_PATH
SIMULATOR
TARGET_CC
TARGET_AS
TARGET_LD
JOB
RESULT_DIR
SVN_SSH
SSH_AUTH_SOCK
SSH_AGENT_PID'

# Run an upper level config if any
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

#
# Tool settings
#
PATH="$DDIR/usr/bin:$DDIR/bin:/bin:/usr/bin"
LDFLAGS="-L$QDIR/usr/lib"
CPPFLAGS="-I$QDIR/usr/include"
LD_LIBRARY_PATH="$DDIR/usr/lib"

restart_clean_env "$@"

