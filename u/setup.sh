#!/bin/sh

. "$DDIR"/config.sh

#
# Settings
#
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

function install_plugins {
  
  local plugins_dir=$HUDSON_HOME/plugins/
  
  mkdir -p $plugins_dir


   wget_newer http://mirrors.ibiblio.org/pub/mirrors/maven2/org/jvnet/hudson/plugins/email-ext/2.9/email-ext-2.9.hpi || true

  mv "$DDIR"/timestamp/email-ext-2.9.hpi $plugins_dir/email-ext.hpi 
}

#
# Executions starts here
#
generate_ssh_keypair

check_server

hudson_hide_sensitive_data

if [ "$1" != "--nostart" ]; then
  install_plugins 

  # Update Hudson
  wget_dist "$HUDSON_URL"

  # Launch Hudson
  java -DHUDSON_HOME="$HUDSON_HOME" -jar "$DDIR"/timestamp/hudson.war
fi

