#!/bin/sh

. "$DDIR"/config.sh

function install_plugins {
  local plugins_dir=$HUDSON_HOME/plugins/
  
  mkdir -p $plugins_dir
  wget_newer http://hudson-ci.org/latest/email-ext.hpi || true
}

#
# Executions starts here
#
check_ssh
hudson_hide_sensitive_data

case " $* " in
  *\ --relink\ *)
    hudson_relink_workspaces
    ;;
  *\ --nostart\ *)
    break
    ;;
  *)
    wget_dist "$HUDSON_URL"
    install_plugins
    unset JOBSTAMP WORKSPACE_DIR RESULT_DIR
    java -DHUDSON_HOME="$HUDSON_HOME" -jar "$DDIR"/timestamp/hudson.war
    ;;
esac

