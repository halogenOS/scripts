# Project description
# This is usually only used for halogenOS
# But to make it a bit easier to set up for other ROMs,
# you can specify the details in your jenkins shell
# build step. Do not modify this file for that.
# Check the build.sh file in this directory for that
# In the _check_vars function there is everything
# that you need.

# build, reposync, reporesync, resetmanifest, ...
if [ "$Supports_xos_tools" == "true" ]; then
  SUPPORTS_XOSTOOLS=true
else
  SUPPORTS_XOSTOOLS=false
fi

