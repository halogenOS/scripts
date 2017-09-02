# Telegram upload

_check_vars_uplprov_telegram() {
  for var in \
      TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID_SCRIPT
  do
    if [ -z "${!var}" ]; then
      echo "Variable '$var' not defined or empty!"
      return 1
    fi
  done
  return 0
}

# $1: file
upload_telegram() {
  echo "Uploading to Telegram..."
  _check_vars_uplprov_telegram
  curl -F chat_id="$($TELEGRAM_CHAT_ID_SCRIPT)" -F document="@$1" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
}
