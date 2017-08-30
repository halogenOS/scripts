# SourceForge upload

_check_vars_uplprov_sourceforge() {
  for var in \
      SOURCEFORGE_PROJECT SOURCEFORGE_USER JENKINS_HOME \
  do
    if [ -z "${!var}" ]; then
      echo "Variable '$var' not defined or empty!"
      return 1
    fi
  done
  return 0
}

# $1: file
upload_sourceforge() {
  echo "Uploading to sourceforge..."
  _check_vars_uplprov_sourceforge
  scp -o StrictHostKeyChecking=no -i $JENKINS_HOME/.ssh/id_rsa "$1" $SOURCEFORGE_USER@frs.sourceforge.net:/home/frs/project/$SOURCEFORGE_PROJECT/$SOURCEFORGE_PATH
}
