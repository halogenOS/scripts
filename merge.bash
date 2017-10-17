source=$(pwd)
tag=android-8.0.0_r17
xos_ver=XOS-8.0
prefix=https://android.googlesource.com/platform/
gerrit_url="ssh://%s@review.halogenos.org:29418/android_%s"

while getopts “opu:” OPTION
do
     case $OPTION in
         o)
             PUSH=true
             ONLY_PUSH=true
             ;;
         p)
             PUSH=true
             ;;
         u)
             GERRIT_USER=$OPTARG
             ;;
     esac
done

for project in $(cat merges.txt); do
  path="$project"
  repo="$project"
  IFS=':' read -r -a array <<< "$project"
  if [ ${#array[@]} -ge 2 ]; then
    path=${array[0]}
    repo=${array[1]}
  fi
  if [ -d $path ]; then
    cd $path
    if [[ ! $ONLY_PUSH ]]; then
      git remote remove aosp 2>/dev/null
      git remote add aosp $prefix$repo
      git fetch XOS $xos_ver
      git reset --hard XOS/$xos_ver
      git pull aosp $tag
    fi
    if [[ $PUSH && ! -z $GERRIT_USER ]]; then
      git remote remove gerrit 2>/dev/null
      git remote add gerrit $(printf $gerrit_url "$GERRIT_USER" $(echo $path | sed 's/\//_/g') )
      git push gerrit HEAD:refs/heads/$xos_ver
    fi
    cd $source
  fi
done
