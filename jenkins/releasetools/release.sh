

do_release() {
  whoami
  cd $ROM_SRC_TOP
  if [ ! -d "extras/ota" ]; then
    git clone ssh://$GERRIT_USER@$GERRIT_REMOTE/$EXTRAS_OTA_REPO extras/ota -b ${ROM_ABBREV_BR}${ROM_VERSION}
  fi
  cd extras/ota
  git pull
  if [[ "$(git remote)" != *"gerrit"* ]]; then
    gitdir=$(git rev-parse --git-dir); scp -p -P $(echo $GERRIT_REMOTE | cut -d ':' -f2) $GERRIT_USER@$(echo $GERRIT_REMOTE | cut -d ':' -f1):hooks/commit-msg ${gitdir}/hooks/
    git remote add gerrit ssh://$GERRIT_USER@$GERRIT_REMOTE/$EXTRAS_OTA_REPO
  fi
  echo "Generating new manifest..."
  XOS_VERSION=$(basename $FINISHED_BUILD | sed -e 's/[.]zip//')
  XOS_VERSION=$XOS_VERSION the_zip=$FINISHED_BUILD ./gen_manifest.bash
  echo "Creating CL"
  git push gerrit HEAD:refs/for/${ROM_ABBREV_BR}${ROM_VERSION}
  echo "Done."
}
