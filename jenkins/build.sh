# source this file from the root of your workspace
# then use the start_build command to start

# Any command fails = the whole thing fails
set -e
# Do not print every single thing that is done
set +x

WORKSPACE_DIR="$(pwd)"
if [ -f "utils.sh" ]; then
  WORKSPACE_DIR="$(realpath $(pwd)/..)"
fi

PLAYGROUND_DIR="$WORKSPACE_DIR/jenkins"

cd "$PLAYGROUND_DIR"

source utils.sh

source project.sh

# You need to have custom functions defined to e. g.
# send notifications to telegram. If you do not,
# the notifications will be printed to stdout
# A _ is prepended to each of the functions to
# prevent collisions with other things.

if ! cmd_exists _sendmsg; then
_sendmsg() {
  echo $@
}
fi

# The actual build script located in build/
source build/build.sh

