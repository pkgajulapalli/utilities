# Add "source PATH_TO_THIS_FILE" at the end of ~/.bash_profile
# Colors
NONE="\[\033[00m\]"
GREEN="\[\033[01;32m\]"
L_CYAN="\[\033[01;36m\]"
BLUE="\[\033[01;34m\]"
YELLOW="\[\033[01;33m\]"
MAGNETA="\[\033[01;35m\]"
export PS1="$GREEN[$L_CYAN\@ $GREEN\u@$YELLOW\h $MAGNETA\W $BLUE\$(git branch 2> /dev/null | grep -e '\* ' | sed 's/^..\(.*\)/{\1}/')$GREEN]\$ $NONE"
export CLICOLOR=1
# TODO: set python venv path here
export WORKSPACE=~/IdeaProjects
export PYTHON_VENV_PATH=${WORKSPACE}/venv/

download_mp3_from_youtube() {
  if [[ ${#} = 1 ]]; then
    youtube_link=$1
    youtube-dl -f 140 ${youtube_link}
  else
    echo "Usage: download_mp3_from_youtube YOUTUBE_VIDEO_LINK"
    return 1
  fi
}

checkout_master() {
  git_branch=$1
  if [ -z ${git_branch} ]; then
    echo "Usage: checkout_master MASTER_BRANCH_NAME"
    return 1
  fi
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout ${git_branch}
  git pull origin ${git_branch}
  if [ ${current_branch} != "${git_branch}" ]; then
    git branch -D ${current_branch}
  else
    echo "Not deleting ${current_branch}"
  fi
}

set_java_version() {
  version=$1
  if [ -z ${version} ]; then
    version=8
    echo -e "Usage: set_java_version VERSION_NUMBER\nDidn't receive argument for version number. Setting to default version ${version}"
  fi

  echo "Setting java version to ${version}"

  if [ ${version} == 11 ]; then
    export JAVA_HOME=${JAVA_11_HOME}
    export PATH=$JAVA_HOME/bin/:$PATH
  else
    export JAVA_HOME=${JAVA_8_HOME}
    export PATH=$JAVA_HOME/bin/:$PATH
  fi
  echo "java -version"
  java -version
}

imdb_actor_search() {
  actor_name=${1}
  echo "Searching for actor: ${actor_name}"
  source ${PYTHON_VENV_PATH}/bin/activate
  working_dir=${PWD}
  cd ${WORKSPACE}/imdb-search/
  python actor_search.py "${actor_name}"
  deactivate
  cd ${working_dir}
}

edit_mkv_file_titles () {
  # Dependencies need to be installed:
  # brew install mkvtoolnix
  # This method takes all mkv files in the current directory and sets the filename
  # (without .mkv) as its title in metadata
  for mkvfile in *.mkv; do
      mkvpropedit "$mkvfile" -e info -s title="${mkvfile%.*}"
  done
}

alias glog='git --no-pager log -n 10 --pretty=oneline'
alias gst='git status'
alias ll='ls -lht'
