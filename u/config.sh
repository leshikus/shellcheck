#!/bin/sh

#
# Software URL Bases
#
GNU_URL=${GNU_URL:-http://mirrors.kernel.org/gnu}
HUDSON_URL=http://hudson.gotdns.com/latest/hudson.war

#
# Load functions
#
DDIR=`cd "$DDIR"; pwd -P`
. "$DDIR"/util.sh

#
# Import shell environment
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
JAVA_HOME
JOB
TIMESTAMP
WORKSPACE_DIR
TMP_DIR
RESULT_DIR
SVN_SSH
SSH_AUTH_SOCK
SSH_AGENT_PID'


#
# Set user environment
#
USER=${USER:-hudson}
HOME=${HOME:-/home/hudson}

prepare_env

# Calculated varaibles
SSH_ID=${SSH_ID:-$USER@$SSH_SERVER}
SSH_PORT=${SSH_PORT:-22}
SVN_SSH="ssh -p $SSH_PORT"

restart_clean_env "$@"

