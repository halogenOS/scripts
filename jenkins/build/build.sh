# Build steps. Has commands for all sorts of things

alias reposync_fallback="repo sync --force-sync --no-clone-bundle --no-tags -c -f -j$(nproc --all)"

_check_vars() {
  for var in \
      WORKSPACE_DIR PLAYGROUND_DIR ROM_NAME ROM_ABBREV  \
      ROM_VERSION SUPPORTS_XOSTOOLS ROM_VENDOR_DIR      \
      ROM_MANIFEST_REPO ROM_ABBREV_BR                   \
                                                        \
      Target_device Do_clean Build_type
  do
    if [ -z "${!var}" ]; then
      echo "Variable '$var' not defined or empty!"
      return 1
    fi
  done
  return 0
}

start_build() {
  # Just to make sure
  set -e
  # Let's go
  echo "Build launched"
  _check_vars
  echo "Workspace: $WORKSPACE_DIR"
  echo "Playground: $PLAYGROUND_DIR"
  echo "ROM name: $ROM_NAME"
  echo "ROM version: $ROM_VERSION"
  echo "XOS Tools support: $SUPPORTS_XOSTOOLS"
  echo "Manifest repo: $ROM_MANIFEST_REPO"
  echo "ROM abbreviation: $ROM_ABBREV"
  echo "ROM abbreviation for branching: $ROM_ABBREV_BR"
  echo "ROM vendor directory: $ROM_VENDOR_DIR"
  echo
  cd "$PLAYGROUND_DIR"

  # cd into the trees dir where we put the rom etc.
  cd trees

  # create a dir for the current version if
  # it does not exist and cd into it
  ROM_SRC_TOP="$ROM_NAME/$ROM_VERSION"
  mkdir -p $ROM_SRC_TOP
  cd $ROM_SRC_TOP

  echo "ROM source directory $ROM_SRC_TOP"

  # check if we already have sources
  [ -d ".repo" ] && HAVE_REPO_SRC=true || HAVE_REPO_SRC=false

  # if there are no sources, init
  if ! $HAVE_REPO_SRC; then
    repo init -u $ROM_MANIFEST_REPO.git -b ${ROM_ABBREV_BR}${ROM_VERSION}
  fi

  # if we have xostools, use that. If not, fallback to traditional
  if $SUPPORTS_XOSTOOLS; then
    if ! [ -d "$ROM_VENDOR_DIR" ]; then
      # We only support 7.1+
      if [ "$ROM_VERSION" != "7.1" ]; then
        if ! [ -d "build/make" -a -d "build/soong" -a -d "build/kati" ]; then
          # Need to download these first
          reposync_fallback build/make
          reposync_fallback build/soong
          reposync_fallback build/kati
          reposync_fallback $ROM_VENDOR_DIR
        fi
      else
        if ! [ -d "build" ]; then
          reposync_fallback build
          reposync_fallback $ROM_VENDOR_DIR
        fi
      fi # ROM_VERSION
    fi # Vendor dir does not exist
    # Setup env so that we get xostools
    source build/envsetup.sh
    if ! $HAVE_REPO_SRC; then
      reposync
    else
      reposync fast
    fi
  else
    # Traditional, but faster
    reposync_fallback
    source build/envsetup.sh
  fi # SUPPORTS_XOSTOOLS

  # Sync is done. We already did envsetup.
  if $SUPPORTS_XOSTOOLS; then
    # Start the build
    build full ${ROM_ABBREV}_${Target_device}-${Build_type} $(${Do_clean} && echo "noclean")
  else
    # Assume bacon support
    breakfast $Target_device
    lunch $Target_device
    make -j$(($(nproc --all)*4)) bacon
  fi

  return 0
}
