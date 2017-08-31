# Initial upload script
# include other upload scripts here

UPLOAD_SH_DIR="$PLAYGROUND_DIR/upload"
UPLOAD_PRV_DIR="$UPLOAD_SH_DIR/providers"

source $UPLOAD_PRV_DIR/sourceforge.sh
source $UPLOAD_PRV_DIR/ftp.sh

# $1: provider
# $2: file
_do_upload() {
  if [ -z "$KBPS_SPEED" ]; then
    echo "KBPS_SPEED not defined!"
    return 1
  fi
  WHAT_IS_UPLOADING="build"
  if [ ! -z "$Module_to_build" ]; then
    WHAT_IS_UPLOADING="module $Module_to_build"
  fi
  FILE_SIZE_IN_BYTES=$(stat --printf="%s" $2)
  FILE_SIZE_IN_MiB=$(echo "scale=2;$FILE_SIZE_IN_BYTES/1024/1024" | bc)
  _sendmsg "The $WHAT_IS_UPLOADING for $Target_device is uploading ($1)
File size: $FILE_SIZE_IN_MiB MiB
Estimated upload duration: $(($FILE_SIZE_IN_BYTES / (1024/8) / $KBPS_SPEED / 60)) minutes"
  upload_$1 $2
}
