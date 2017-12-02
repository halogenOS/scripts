

do_release() {
  whoami
  cd $ROM_SRC_TOP
  cd extras/ota
  echo "Generating new manifest..."
  XOS_VERSION=$(basename $FINISHED_BUILD | sed -e 's/[.]zip//')
  XOS_VERSION=$XOS_VERSION the_zip=$FINISHED_BUILD ./gen_manifest.sh
  echo "Creating OTA commit"
  git add -A
  git commit -m "$XOS_VERSION"
  echo "Creating CL"
  if [[ "$(git remote)" != *"gerrit"* ]]; then
    git remote add gerrit ssh://$GERRIT_USER@$GERRIT_REMOTE/$EXTRAS_OTA_REPO
  fi
  git push gerrit HEAD:refs/for/${ROM_ABBREV_BR}${ROM_VERSION}
  echo "Done."
}
