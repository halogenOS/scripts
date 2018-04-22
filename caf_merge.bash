#!/bin/bash
# Variables
SOURCE=$(pwd)
SCRIPT_PROJECT="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
source ${SCRIPT_PROJECT}/common

[[ -d ${SOURCE}/.repo/manifests/ ]] || exit "Run this from the root of your source tree"
TAG=""
XOS_VER=XOS-8.1
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

echo -e "\033[01;31m Merging tag \033[01;33m ${TAG:?} \033[0m"

for PROJECT in $(cat ${SCRIPT_PROJECT}/caf_repos.txt); do
  if [ -d ${PROJECT} ]; then
    XOS_UPSTREAM_VER=${XOS_VER}
    [[ ${PROJECT} =~ "-caf" ]] && XOS_UPSTREAM_VER="${XOS_VER}-caf"
    cd ${PROJECT}
    if [[ ! ${ONLY_PUSH} ]]; then
      cafremote ${SOURCE}
      git fetch XOS ${XOS_VER}
      git reset --hard XOS/${XOS_VER}
      git fetch caf --tags
      git merge ${TAG}
    fi
    if [[ ${PUSH} && ! -z ${GERRIT_USER} ]]; then
      git remote remove gerrit 2>/dev/null
      git remote add gerrit $(printf ${GERRIT_URL} "${GERRIT_USER}" $(echo ${PROJECT} | sed -e 's/\//_/g' -e 's/-caf//'))
      git push gerrit HEAD:refs/heads/${XOS_UPSTREAM_VER}
    fi
    cd ${SOURCE}
  fi
done