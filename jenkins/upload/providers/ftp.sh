# FTP upload

_check_vars_uplprov_ftp() {
  for var in \
        FTP_HOST FTP_USER FTP_PASSWD_FILE FTP_PATH \
  do
    if [ -z "${!var}" ]; then
      echo "Variable '$var' not defined or empty!"
      return 1
    fi
  done
  return 0
}

# $1: file
upload_ftp() {
  echo "Uploading using FTP..."
  _check_vars_uplprov_ftp
  HOST="$FTP_HOST"
  USER="$FTP_USER"
  PASSWD="$(cat $FTP_PASSWD_FILE)"
  FILE="$1"

  cd $(dirname $(realpath "$FILE"))

  ftp-ssl -n -v -p $HOST << EOT
user $USER $PASSWD
prompt
cd $FTP_PATH
put $FILE
bye
EOT

  unset HOST
  unset USER
  unset PASSWD
  unset FILE
}
