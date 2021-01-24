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

logger() {
  level=$1
  message=$2
  echo "`date '+%Y-%m-%d %H:%M:%S'`: ${level} : ${message}"
}

activate_python_venv() {
  logger DEBUG "Activating Python virtual environment"
  source ${PYTHON_VENV_PATH}/bin/activate
}

deactivate_python_venv() {
  logger DEBUG "Deactivating Python virtual environment"
  deactive
}

get_cron_expression() {
  minutes=$1
  echo $(date -v+${minutes}M "+%M %H %d")
}

remove_entry_from_cron() {
  temp_file_name=$1
  # update the cronjob
  cron_file=$(mktemp)
  crontab -l | grep -v "${temp_file_name}" > ${cron_file}
  crontab ${cron_file}
  rm ${cron_file}
  # remove the file
  rm ${temp_file_name}

}

voice_reminder() {
  minutes=$1
  message=$2

  # create temporary file
  temp_file=$(mktemp)
  # set the file content
  echo "say ${message}" > ${temp_file}
  echo "source ~/.my_functions.sh && remove_entry_from_cron \"${temp_file}\"" >> ${temp_file}
  # make the temp file executable
  chmod +x ${temp_file}
  # schedule the file to run at specified time
  cron_file=$(mktemp)
  crontab -l > ${cron_file}
  cron_expression=$(get_cron_expression $minutes)
  echo "${cron_expression} * * bash ${temp_file}" >> ${cron_file}
  crontab ${cron_file}
  rm ${cron_file}
}

download_mp3_from_youtube() {
  if [[ ${#} = 1 ]]; then
    youtube_link=$1
    activate_python_venv
    youtube-dl -f 140 ${youtube_link}
    deactivate_python_venv
  else
    logger ERROR "Usage: download_mp3_from_youtube YOUTUBE_VIDEO_LINK"
    return 1
  fi
}

checkout_master() {
  git_branch=$1
  if [ -z ${git_branch} ]; then
    logger ERROR "Usage: checkout_master MASTER_BRANCH_NAME"
    return 1
  fi
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout ${git_branch}
  git pull origin ${git_branch}
  if [ ${current_branch} != "${git_branch}" ]; then
    git branch -D ${current_branch}
  else
    logger INFO "Not deleting ${current_branch}"
  fi
}

set_java_version() {
  version=$1
  if [ -z ${version} ]; then
    version=8
    logger ERROR -e "Usage: set_java_version VERSION_NUMBER\nDidn't receive argument for version number. Setting to default version ${version}"
  fi

  logger INFO "Setting java version to ${version}"

  if [ ${version} == 11 ]; then
    export JAVA_HOME=${JAVA_11_HOME}
    export PATH=$JAVA_HOME/bin/:$PATH
  else
    export JAVA_HOME=${JAVA_8_HOME}
    export PATH=$JAVA_HOME/bin/:$PATH
  fi
  logger INFO "java -version"
  java -version
}

imdb_search() {
  person_name=${1}
  logger INFO "Searching for actor: ${person_name}"
  activate_python_venv
  working_dir=${PWD}
  cd ${WORKSPACE}/imdb-search/
  python movie_search.py "${person_name}"
  deactivate_python_venv
  cd ${working_dir}
}

edit_mkv_file_titles() {
  # Dependencies need to be installed:
  # brew install mkvtoolnix
  # This method takes all mkv files in the current directory and sets the filename
  # (without .mkv) as its title in metadata
  for mkvfile in *.mkv; do
    # edit the title
    mkvpropedit "$mkvfile" -e info -s title="${mkvfile%.*}"
    # edit the subtitle track name
    mkvpropedit "$mkvfile" -e track:s1 -s name="${mkvfile%.*}"
  done
}

enter_incognito_mode() {
  unset HISTFILE
}

exit_incognito_mode() {
  if [ -z "$HISTFILE" ]; then
   HISTFILE="~/.bash_history"
  fi
}

alias glog='git --no-pager log -n 10 --pretty=oneline'
alias gst='git status'
alias ll='ls -lht'
