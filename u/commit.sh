#!/bin/sh

DDIR=`dirname "$0"`
. "$DDIR"/config.sh

check_ssh

ssh -p $SSH_PORT $SSH_ID "
set -e$-
mkdir -p /tmp/$USER/commit
cd /tmp/$USER/commit
export SVN_SSH='ssh -p $SSH_PORT'
test -d trunk/.svn && svn revert -R trunk
nice svn co $SVN_URL/trunk

rm -rf build
mkdir -p build
" &
pid=$!

PATCH="$TMP_JOB_DIR"/"$CUR_DIR_NAME".patch
svn info | perl -e '
while (<>) {
  if (/^URL: (.*)$/) { $url = $1; }
  if (/^Repository Root: (.*)$/) { $root = $1; }
}
$url =~ s/\Q$root\E//;
print $url;
' >"$PATCH"
PATCH_PATH=`cat "$PATCH"`

svn diff | tee "$PATCH"

echo Please review the patch...
wait $!

scp -P $SSH_PORT "$PATCH" $SSH_ID:/tmp/$USER/commit

ssh -p $SSH_PORT $SSH_ID "
set -e$-
cd '/tmp/$USER/commit$PATCH_PATH'
patch -p0 <'/tmp/$USER/commit/$CUR_DIR_NAME.patch'
cd /tmp/$USER/commit/build
'$CMAKE_PATH/cmake' /tmp/$USER/commit/trunk 2>&1 | tee cmake.log
grep '^CMake Error' cmake.log && exit 1 || true
nice make
nice make checkin-ok
"

echo "Go ahead and commit, please"

