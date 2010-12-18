#!/bin/sh

DDIR=`dirname "$0"`
. "$DDIR"/config.sh

sudo yum install zlib-devel.$ARCH subversion.$ARCH gcc.$ARCH gcc-c++.$ARCH expect.$ARCH gnupg.$ARCH

