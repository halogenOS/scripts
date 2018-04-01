# Variables
SOURCE=$(pwd)
SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
TAG=android-8.1.0_r18
XOS_VER=XOS-8.1
PREFIX=https://android.googlesource.com/platform/
GERRIT_URL="ssh://%s@review.halogenos.org:29418/android_%s"

while getopts “opu:t:” OPTION; do
  case ${OPTION} in
      o)
        PUSH=true
        ONLY_PUSH=true
        ;;
      p)
        PUSH=true
        ;;
      u)
        GERRIT_USER=${OPTARG}
        ;;
      t)
        TAG=${OPTARG}
        ;;
  esac
done

for PROJECT in $(cat ${SCRIPT_DIR}/merges.txt); do
  PATH="${PROJECT}"
  REPO="${PROJECT}"
  IFS=':' read -r -a array <<< "${PROJECT}"
  if [ ${#array[@]} -ge 2 ]; then
    PATH=${array[0]}
    REPO=${array[1]}
  fi
  if [ -d ${PATH} ]; then
    cd ${PATH}
    if [[ ! ${ONLY_PUSH} ]]; then
      git remote remove aosp 2>/dev/null
      git remote add aosp ${PREFIX}${REPO}
      git fetch XOS ${XOS_VER}
      git reset --hard XOS/${XOS_VER}
      git pull aosp ${TAG}
    fi
    if [[ ${PUSH} && ! -z ${GERRIT_USER} ]]; then
      git remote remove gerrit 2>/dev/null
      git remote add gerrit $(printf ${GERRIT_URL} "${GERRIT_USER}" $(echo ${PATH} | sed 's/\//_/g'))
      git push gerrit HEAD:refs/heads/${XOS_VER}
    fi
    cd ${SOURCE}
  fi
done