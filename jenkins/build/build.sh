# Build steps. Has commands for all sorts of things

reposync_fallback() {
 repo sync --force-sync --no-clone-bundle --no-tags -c -f -j$(nproc --all) $@
}

_check_vars() {
  for var in \
      WORKSPACE_DIR PLAYGROUND_DIR ROM_NAME ROM_ABBREV  \
      ROM_VERSION SUPPORTS_XOSTOOLS ROM_VENDOR_DIR      \
      ROM_MANIFEST_REPO ROM_ABBREV_BR                   \
                                                        \
      Target_device Do_clean Build_type Enable_ccache   \
      Only_upload
  do
    if [ -z "${!var}" ]; then
      echo "Variable '$var' not defined or empty!"
      return 1
    fi
  done
  return 0
}

BUILD_START_DATE="$(date +%Y%m%d)"

start_build() {
  # Just to make sure
  set -e
  # Let's go
  echo "Build launched"
  _check_vars
  [ -z "$Do_release" ] && DO_RELEASE=false || DO_RELEASE=$Do_release
  echo "Workspace: $WORKSPACE_DIR"
  echo "Playground: $PLAYGROUND_DIR"
  echo "ROM name: $ROM_NAME"
  echo "ROM version: $ROM_VERSION"
  echo "XOS Tools support: $SUPPORTS_XOSTOOLS"
  echo "Manifest repo: $ROM_MANIFEST_REPO"
  echo "ROM abbreviation: $ROM_ABBREV"
  echo "ROM abbreviation for branching: $ROM_ABBREV_BR"
  echo "ROM vendor directory: $ROM_VENDOR_DIR"
  echo "ROM-specific external directory: $ROM_EXTERNAL_DIR"
  echo "Target device: $Target_device"
  echo "Clean: $Do_clean"
  echo "Build type: $Build_type"
  echo "Repopick stuff: $repopick_before_build"
  echo "Sync: $do_sync"
  echo "Reset: $do_reset"
  echo "CCache: $Enable_ccache, dir: $CCACHE_DIR"
  echo "Java options: $_JAVA_OPTIONS"
  echo
  cd "$PLAYGROUND_DIR"

  if $Enable_ccache; then
    CCACHE_SIZE=${CCACHE_SIZE:=80G}

    if [ ! -e "$CCACHE_DIR" ]; then
      mkdir -p "$CCACHE_DIR"
      ccache -M $CCACHE_SIZE
    fi
  fi

  # check if repo tool is installed
  mkdir -p $PLAYGROUND_DIR/bin
  export PATH="$PLAYGROUND_DIR/bin:$PATH"
  which repo 2>/dev/null >/dev/null || (
    curl https://storage.googleapis.com/git-repo-downloads/repo > $PLAYGROUND_DIR/bin/repo && \
    chmod a+x $PLAYGROUND_DIR/bin/repo
  )

  # cd into the trees dir where we put the rom etc.
  cd trees

  # create a dir for the current version if
  # it does not exist and cd into it
  ROM_SRC_TOP="$(realpath $ROM_NAME/$ROM_VERSION)"
  mkdir -p $ROM_SRC_TOP
  cd $ROM_SRC_TOP

  echo "ROM source directory $ROM_SRC_TOP"

  if $Only_upload; then
    upload_cake
    return 0
  fi

  # check if we already have sources
  [ -d ".repo" ] && HAVE_REPO_SRC=true || HAVE_REPO_SRC=false

  # if there are no sources, init
  if ! $HAVE_REPO_SRC; then
    repo init -u $ROM_MANIFEST_REPO.git -b ${ROM_ABBREV_BR}${ROM_VERSION}
  fi

  # if we have xostools, use that. If not, fallback to traditional
  if $SUPPORTS_XOSTOOLS; then
    if [ ! -d "$ROM_VENDOR_DIR" ] || ( [ ! -z "$ROM_EXTERNAL_DIR" ] && [ ! -d "$ROM_EXTERNAL_DIR" ] ); then
      # We only support 7.1+
      if [ "$ROM_VERSION" != "7.1" ]; then
        if ( ! [ -d "build/make" -a -d "build/soong" -a -d "build/kati" -a -d "$ROM_VENDOR_DIR" ] ) || \
           ( [ ! -z "$ROM_EXTERNAL_DIR" ] && [ ! -d "$ROM_EXTERNAL_DIR" ] ); then
          # Need to download these first
          reposync_fallback build/make
          reposync_fallback build/soong
          reposync_fallback build/kati
          reposync_fallback $ROM_VENDOR_DIR
          if [ ! -z "$ROM_EXTERNAL_DIR" ]; then
            reposync_fallback $ROM_EXTERNAL_DIR
          fi
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
    REPOSYNC_SPEED=$Reposync_speed
    if ! $HAVE_REPO_SRC; then
      if [ "$Reposync_speed" == "default" ] || [ "$Reposync_speed" == "auto" ]; then
        REPOSYNC_SPEED=
      fi
    else
      REPOSYNC_SPEED=$Reposync_speed
      if [ "$Reposync_speed" == "default" ]; then
        REPOSYNC_SPEED=fast
      elif [ "$Reposync_speed" == "auto" ]; then
        REPOSYNC_SPEED=
      fi
    fi
    if [ "$Do_resync" == "true" ]; then
      reporesync full confident
    else
      if [ "$do_sync" != "false" ]; then
        # To make sure that there are no changes
        # in the hardware repos, remove them and
        # let reposync sync add them back properly
        rm -rf hardware/
      fi
      if [ "$do_reset" != "false" ]; then
        set +e
        resetmanifest
        reposterilize
        set -e
      fi
      if [ "$do_sync" != "false" ]; then
        reposync $REPOSYNC_SPEED
      fi
    fi
  else
    if [ "$do_sync" != "false" }; then
      # Traditional, but faster
      reposync_fallback
    fi
  fi # SUPPORTS_XOSTOOLS
  source build/envsetup.sh

  if [ "$DO_BREAKFAST" != "false" ]; then
    breakfast ${Target_device} || :
  fi

  if [ ! -z "$repopick_before_build" ]; then
    IFS='
'
    for piki in $(echo "$repopick_before_build" | sed -e 's/\[\[NEWLINE\]\]/\n/g' | sed -e 's/\[\[SPACE\]\]/ /g'); do
      unset IFS
      if [[ "$piki" == "local "* ]]; then
        pikidir=$(echo "$piki" | cut -d ' ' -f2)
        pikidst=$(echo "$piki" | cut -d ' ' -f3)
        pikirev=$(echo "$piki" | cut -d ' ' -f4)
        pikicmt=$(echo "$piki" | cut -d ' ' -f5)
        cd $ROM_SRC_TOP/$pikidst
        git fetch $pikidir $pikirev
        git cherry-pick $pikicmt
        cd $ROM_SRC_TOP
      elif [[ "$piki" == "local-reset "* ]]; then
        pikidir=$(echo "$piki" | cut -d ' ' -f2)
        pikidst=$(echo "$piki" | cut -d ' ' -f3)
        pikirev=$(echo "$piki" | cut -d ' ' -f4)
        cd $ROM_SRC_TOP/$pikidst
        git fetch $pikidir
        git reset --hard $pikirev
        cd $ROM_SRC_TOP
      elif [[ "$piki" == "remote-reset "* ]]; then
        pikidir=$(echo "$piki" | cut -d ' ' -f2)
        pikidst=$(echo "$piki" | cut -d ' ' -f3)
        pikirev=$(echo "$piki" | cut -d ' ' -f4)
        pikicmt=$(echo "$piki" | cut -d ' ' -f5 || true)
        cd $ROM_SRC_TOP/$pikidst
        rid=$(echo "$pikidir" | sha256sum | cut -d ' ' -f1)
        echo "remote-reset: Generated $rid"
        git remote add $rid $pikidir || :
        git fetch $rid
        if [ "$pikicmt" == "rev" ]; then
          git reset --hard $pikirev
        else
          git reset --hard $rid/$pikirev
        fi
        cd $ROM_SRC_TOP
      elif [[ "$piki" == "sync" ]]; then
        if $SUPPORTS_XOSTOOLS; then
          reposync $REPOSYNC_SPEED
        else
          reposync_fallback
        fi
      elif [[ "$piki" == "reset-here "* ]]; then
        pikidir=$(echo "$piki" | cut -d ' ' -f2)
        pikirev=$(echo "$piki" | cut -d ' ' -f3)
        cd $ROM_SRC_TOP/$pikidir
        git fetch $(echo "$pikirev" | cut -d '/' -f1)
        git reset --hard $pikirev
        cd $ROM_SRC_TOP
      elif [[ "$piki" == "clone "* ]]; then
        pikirem=$(echo "$piki" | cut -d ' ' -f2)
        pikidir=$(echo "$piki" | cut -d ' ' -f3)
        pikirev=$(echo "$piki" | cut -d ' ' -f4)
        git clone $pikirem $pikidir -b $pikirev
      elif [[ "$piki" == "fetch-file "* ]]; then
        pikifile=$(echo "$piki" | cut -d ' ' -f2)
        pikidest=$(echo "$piki" | cut -d ' ' -f3 | sed -e 's/[.][.]/dotdot/g')
        curl https://raw.githubusercontent.com/$pikifile > $pikidest
        if [[ "$pikidest" == ".repo/"* ]]; then
          if $SUPPORTS_XOSTOOLS; then
            reposync $REPOSYNC_SPEED
          else
            reposync_fallback
          fi
        fi
      else
        set +e
        fpiki=${piki//,/ }
        repopick $fpiki
        if [ $? -ne 0 ]; then
          _sendmsg "Repopick failed for $BUILD_TAG"
          set -e
          return 1
        fi
        set -e
      fi
      IFS='
'
    done
    unset IFS
  fi

  # One more time just to be on the safe side
  source build/envsetup.sh

  # Sync is done. We already did envsetup.
  if [ -z "$Module_to_build" ]; then
    _sendmsg "Build for $Target_device started"
  else
    _sendmsg "Build of module $Module_to_build for $Target_device started"
  fi
  if $SUPPORTS_XOSTOOLS; then
    # Start the build
    set +e
    ret=0
    build \
        $([ -z "$Module_to_build" ] && echo "full" || echo "module") \
        ${ROM_ABBREV}_${Target_device}-${Build_type} \
        $(${Do_clean} || echo "noclean") $Module_to_build
    ret=$?
    if [ $ret -ne 0 ]; then
      _sendmsg "Build [$BUILD_DISPLAY_NAME]($BUILD_URL) failed."
    fi
    set -e
    if [ $ret -ne 0 ]; then
      return $ret
    fi
  else
    [ -z "$Module_to_build" ] && MODULE_TO_BUILD="$Module_to_build" || \
                                 MODULE_TO_BUILD="bacon"
    # Assume bacon support
    breakfast $Target_device
    lunch ${ROM_ABBREV}_${Target_device}-${Build_type}
    make -j$(($(nproc --all)*4)) $MODULE_TO_BUILD
  fi

  upload_cake

  return 0
}

upload_cake() {
  echo "Upload started"
  if [ -z "$Module_to_build" ] || [ "$Module_to_build" == "bacon" ] || [ "$Module_to_build" == "otapackage" ]; then
    FINISHED_BUILD="$(ls $ROM_SRC_TOP/out/target/product/$Target_device/${ROM_ABBREV}_${Target_device}_*_$BUILD_START_DATE.zip)"
    if [ ! -z "${Zip_suffix}" ]; then
      BEFORE_FINISHED_BUILD="$FINISHED_BUILD"
      FINISHED_BUILD="${FINISHED_BUILD/.zip/${Zip_suffix}.zip}"
      ln -sf "$BEFORE_FINISHED_BUILD" "$FINISHED_BUILD"
    fi
  else
    set +e
    what_to_upload=""
    case "$Module_to_build" in
      bootimage) what_to_upload="$ROM_SRC_TOP/out/target/product/${Target_device}/boot.img" ;;
      bootzip) what_to_upload="$(ls $ROM_SRC_TOP/out/target/product/${Target_device}/*-kernel.zip)" ;;
      *)
        dafile=$(find $ROM_SRC_TOP/out/target/product/${Target_device}/system/ -name "${Module_to_build}*" -type f)
        if [ -z "$dafile" ]; then
          dafile=$(find $ROM_SRC_TOP/out/target/product/${Target_device}/data/ -name "${Module_to_build}*" -type f)
        fi
        if [ -z "$dafile" ] && [[ "$Module_to_build" == *"_32" ]]; then
          dafile=$(find $ROM_SRC_TOP/out/target/product/${Target_device}/system/ -name "${Module_to_build/_32/}*" -type f)
        fi
        if [ -z "$dafile" ]; then
          dafile=$(find $OM_SRC_TOP/out/target/product/${Target_device}/root/ -name "${Module_to_build}*" -type f)
        fi
        what_to_upload="$dafile"
      ;;
    esac
    set -e
    FINISHED_BUILD="$what_to_upload"
  fi
  upload_cake_topping
}

upload_cake_topping() {
  _upload
  if [ "$USES_ASYNC_HANDLER" == "true" ]; then
    return 0
  fi
  type_of_="build"
  dl_if_applicable="[Download here]($(_get_download_url))"
  if [ ! -z "$Module_to_build" ]; then
    type_of_="module $Module_to_build"
  fi
  if [ ! -z "$Module_to_build" ] && [ "$Force_dl_link" != "true" ]; then
    dl_if_applicable=""
  fi

  if $DO_RELEASE; then
    # For releasing builds
    source $PLAYGROUND_DIR/releasetools/release.sh
    do_release
  fi

  _sendmsg "New $type_of_ - ${ROM_ABBREV} ${ROM_VERSION} - ${Target_device} - $(date +%Y/%m/%d)

*Changelog*:
${Build_changelog}

$dl_if_applicable"

}
