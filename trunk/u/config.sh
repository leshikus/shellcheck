#!/bin/sh

#
# Set software URLs
#
GNU_URL=http://mirrors.kernel.org/gnu
APACHE_URL=http://apache.inetbridge.net
HUDSON_URL=http://hudson.gotdns.com/latest/hudson.war

#
# Import shell environment
# when add to the list do not omit quotes
#
USER="${USER:-hudson}"
HOME="${HOME:-/home/hudson}"

TMP_DIR="${TMP_DIR:-/tmp/$USER}"
WORKSPACE_DIR="${WORKSPACE_DIR}"
RESULT_DIR="${RESULT_DIR}"

SIMULATOR="${SIMULATOR}"
TARGET_CC="${TARGET_CC}"
TARGET_AS="${TARGET_AC}"
TARGET_LD="${TARGET_LD}"

SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
SSH_AGENT_PID="$SSH_AGENT_PID"
SSH_PORT="${SSH_PORT:-22}"

#
# Run configuration scripts
#
. "$DDIR"/set_env.sh

