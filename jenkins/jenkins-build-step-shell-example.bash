
set -e
set +x

export PATH="$JENKINS_HOME/bin:$PATH"

export _JAVA_OPTIONS="-Xmx10G"
$Enable_ccache && export USE_CCACHE=1 || export USE_CCACHE=0
export CCACHE_DIR="/media/CCache/$Target_device-$Rom_version"

ROM_NAME="halogenOS"
ROM_VERSION="$Rom_version"
ROM_ABBREV="XOS"
ROM_ABBREV_BR="XOS-"
Supports_xos_tools=true
ROM_VENDOR_DIR="vendor/xos"
ROM_MANIFEST_REPO="https://github.com/halogenOS/android_manifest"
export BUILD_DISPLAY_NAME="${BUILD_NUMBER}-${Target_device}"
# Whether to use async upload (needs custom implementation)
#export USES_ASYNC_HANDLER=true

SOURCEFORGE_USER="xdevs23"
SOURCEFORGE_PROJECT="halogenos-builds"
SOURCEFORGE_PATH="test_builds/"

FTP_HOST='acc.yourhost.com'
FTP_USER='sampleuser'
FTP_PASSWD_FILE="$JENKINS_HOME/your-secured-passwd.txt"

# Average upload speed in kbit/s
KBPS_SPEED=3500

TELEGRAM_BOT_TOKEN="your api token"
# Script to get the chat id based on device name
TELEGRAM_CHAT_ID_SCRIPT="$(pwd)/custom/tggetchatid"

[ ! -z "$TARGET_FORCE_DEXPREOPT" ] && echo "TARGET_FORCE_DEXPREOPT is deprecated" && exit 1
$Do_release && export WITH_DEXPREOPT=true

if [[ "$repopick_before_build" == *";"* ]] || [[ "$Zip_suffix" == *";"* ]]; then
  echo "Don't do that!"
  exit 1
fi

# Usually not necessary
function getPlatformPath() {
  PWD="$(pwd)"
  original_string="$PWD"
  string_to_replace="$ROM_SRC_TOP"
  result_string="${original_string//$string_to_replace}"
  echo -n "$result_string"
}

# Must be implemented in order to send telegram messages
_sendmsg() {
  Target_device="$Target_device" $WORKSPACE_DIR/custom/tgsendmsg "$@" || true
}

# Async upload
_upload_new() {
  changelog_file=/tmp/$(basename $FINISHED_BUILD)-changelog.txt
  echo "$Build_changelog" > $changelog_file
  echo "upload $FINISHED_BUILD $Do_release $Target_device $Module_to_build $ROM_VERSION" > /var/lib/jenkins/upload.fifo
  echo "Waiting for copy to complete..."
  while ! stat /tmp/upload-daemon.1.cpdone 2>/dev/null; do sleep 1; done
  rm -f /tmp/upload-daemon.1.cpdone
}

# Must be implemented
_upload() {
  # Replace this with _upload_old for sync upload
  _upload_new || (
    echo "New failed, falling back to synchronous.";
    _upload_old
  )
}

# Synced upload
_upload_old() {
  echo "Custom upload function invoked."
  if $Do_release; then
     SOURCEFORGE_PROJECT="halogenos"
     SOURCEFORGE_PATH="$Target_device/"
     FTP_PATH="upload/ROM/halogenOS/$(echo "$ROM_VERSION" | cut -d '.' -f1)/"
    _do_upload sourceforge $FINISHED_BUILD
    _do_upload ftp $FINISHED_BUILD
  else
    if [ -z "$Module_to_build" ]; then
       _do_upload sourceforge $FINISHED_BUILD
      changelog_file=/tmp/$(basename $FINISHED_BUILD)-changelog.txt
      echo "$Build_changelog" > $changelog_file
      upload_sourceforge $changelog_file
      _sendmsg "Waiting for sourceforge..."
      sleep $((60*2))
    else
      _do_upload telegram $FINISHED_BUILD
    fi
  fi
  echo "Custom upload function exiting"
}

_get_download_url() {
  echo "https://sourceforge.net/projects/$SOURCEFORGE_PROJECT/files/${SOURCEFORGE_PATH}$(basename $FINISHED_BUILD)/download"
}

source /home/simao/sthdd/data/jenkins/workspace/halogenOS/jenkins/build.sh

if [ $Just_clean == true ]; then
  THE_OUT_DIR="$PLAYGROUND_DIR/trees/$ROM_NAME/$ROM_VERSION/out"
  echo "Deleting out dir $THE_OUT_DIR"
  rm -rf $THE_OUT_DIR
  exit $?
fi

start_build
