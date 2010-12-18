#!/bin/sh

. "$DDIR"/util.sh

#
# Settings
#
HUDSON_URL=http://hudson.gotdns.com/latest/hudson.war
HUDSON_HOME="$DDIR"/../hudson_home
HUDSON_KEY_DIR="$HUDSON_HOME"/subversion-credentials
KEY_NAME="$HOME"/.ssh/id_rsa

#
# Functions
#
function generate_ssh_keypair() {

  test -f "$KEY_NAME" ||
    ssh-keygen -N "" -f "$KEY_NAME"
}

function check_server() {
  cat "$KEY_NAME".pub |
    ssh -p $SSH_PORT $SSH_ID \
    'read key; grep -Fx "$key" $HOME/.ssh/authorized_keys2 || echo "$key" >>$HOME/.ssh/authorized_keys2'
}

function hide_sensitive_data() {
  # Keep private keys safe
  mkdir -p "$HUDSON_KEY_DIR"
  chmod 700 "$HUDSON_KEY_DIR"
}

function install_plugins {
  
  local plugins_dir=$HUDSON_HOME/plugins/
  
  mkdir -p $plugins_dir

  wget_newer http://hudson-ci.org/latest/email-ext.hpi
  mv "$DDIR"/timestamp/email-ext.hpi $plugins_dir 
}

#
# Executions starts here
#
generate_ssh_keypair

check_server

hide_sensitive_data

install_plugins

# Update Hudson
wget_dist "$HUDSON_URL"

# Launch Hudson
java -DHUDSON_HOME="$HUDSON_HOME" -jar "$DDIR"/timestamp/hudson.war

