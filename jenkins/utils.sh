
cmd_exists() {
  type $1 2>/dev/null >/dev/null
  return $?
}
