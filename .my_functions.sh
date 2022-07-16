# Add "source PATH_TO_THIS_FILE" at the end of ~/.bash_profile
# Colors
NONE="\[\033[00m\]"
GREEN="\[\033[01;32m\]"
L_CYAN="\[\033[01;36m\]"
BLUE="\[\033[01;34m\]"
YELLOW="\[\033[01;33m\]"
MAGNETA="\[\033[01;35m\]"
export PS1="${GREEN}[$L_CYAN\@ $GREEN\u@$YELLOW\h $MAGNETA\W $BLUE\$(git branch 2> /dev/null | grep -e '\* ' | sed 's/^..\(.*\)/{\1}/')$GREEN]\$ $NONE"
export CLICOLOR=1

# TODO: update the workspace folder
export WORKSPACE=~/IdeaProjects
# TODO: set python venv path here
export PYTHON_VENV_PATH=${WORKSPACE}/venv/
# TODO: store github token here
export GITHUB_TOKEN_FILE=${WORKSPACE}/.my_github_token

logger() {
  level=$1
  message=$2
  echo "$(date '+%Y-%m-%d %H:%M:%S'): ${level} : ${message}"
}

get_default_value() {
  arg_name=$1
  default_value=$2
  actual_value=$3
  if [ -z "${actual_value}" ]; then
    logger DEBUG "Value is null. Returning default value (${default_value}) for argument ${arg_name}"
    return ${default_value}
  else
    logger DEBUG "Value is not null. Returning the same (${actual_value}) for argument ${arg_name}"
    return ${actual_value}
  fi
}

copy_github_token() {
  if [ ! -f ${GITHUB_TOKEN_FILE} ]; then
    logger ERROR "${GITHUB_TOKEN_FILE} file is not found"
  fi
  pbcopy < ${GITHUB_TOKEN_FILE}
}

activate_python_venv() {
  logger DEBUG "Activating Python virtual environment"
  source ${PYTHON_VENV_PATH}/bin/activate
}

deactivate_python_venv() {
  logger DEBUG "Deactivating Python virtual environment"
  deactivate
}

get_cron_expression() {
  minutes=$1
  date -v+${minutes}M "+%M %H %d"
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

: '
TODO: provide Full Disk Access (System Preferences > Security & Privacy > Privacy > Full Disk Access) to /usr/sbin/cron

USAGE: voice_reminder NUM_OF_MINUTES_TO_WAIT "MESSAGE_TO_BE_SAID"
eg: voice_reminder 10 "check charging"
'
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

install_youtube_dl() {
  activate_python_venv
  pip install -U youtube-dl
  deactivate_python_venv
}

: '
TODO: install_youtube_dl
'
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

: '
TODO: set local java home folders
'
set_java_version() {
  version=$1
  if [ -z ${version} ]; then
    version=8
    logger ERROR -e "Usage: set_java_version VERSION_NUMBER\nDidn't receive argument for version number. Setting to default version ${version}"
  fi

  # shellcheck disable=SC2034
  new_java_home_variable_name="JAVA_${version}_HOME"
  eval "new_java_home=\$${new_java_home_variable_name}"
  if [ -z "${new_java_home}" ]; then
    logger WARN "${new_java_home_variable_name} variable is not set"
  elif [ -d ${new_java_home} ]; then
    logger INFO "Setting java version to ${version}"
    eval "export JAVA_HOME=\$${new_java_home_variable_name}"
    export PATH=$JAVA_HOME/bin/:$PATH
  else
    logger WARN "JAVA_${version}_HOME: ${new_java_home} directory does not exist."
  fi

  logger INFO "java -version"
  java -version
}

imdb_search() {
  person_name=${1}
  logger INFO "Searching for actor: ${person_name}"
  activate_python_venv
  working_dir=${PWD}
  cd ${WORKSPACE}/imdb-search/ || return 1
  python movie_search.py "${person_name}"
  deactivate_python_venv
  cd ${working_dir} || return 1
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
   HISTFILE="${HOME}/.bash_history"
  fi
}

start_python_server() {
  activate_python_venv
  python -m http.server 8000
  logger INFO "python http server is stopped"
  deactivate_python_venv
}

turn_on_wifi() {
  /usr/sbin/networksetup -setairportpower Wi-Fi on
}

turn_off_wifi() {
  /usr/sbin/networksetup -setairportpower Wi-Fi off
}

repeat_command() {
  command_to_execute=$1

  get_default_value "time_to_wait" 10 $2
  time_to_wait=$? # in seconds

  get_default_value "num_retries" 50 $3
  num_retries=$? # num of retries allowed

  get_default_value "retry" 0 $4
  retry=$? # retry number

  script_file=$(mktemp)
  echo "$command_to_execute" > ${script_file}
  bash ${script_file}
  if [ $? != 0 ]; then
    if [ ${retry} -gt ${num_retries} ]; then
      logger INFO "Reached max number of retries(${num_retries}). Not retrying."
      return 1
    fi
    logger INFO "Retry #${retry} failed. Repeating in ${time_to_wait} seconds..."
    sleep ${time_to_wait}
    repeat_command "${command_to_execute}" ${time_to_wait} ${num_retries} $((retry+1))
  fi
}

# git aliases
alias glog='git --no-pager log -n 10 --pretty=oneline'
alias gst='git status'
alias gd='git diff'
alias gb="git branch | grep -e '\* ' | awk '{print \$2}'"
alias gc='git checkout'
alias gcb='git checkout -b'
alias gpo='b=$(gb);git push -u origin ${b}'
alias gcp='git cherry-pick'
alias gcam='git commit -a -m'
alias ll='ls -lht'

# maven aliases
alias mci='mvn clean install'
alias mcist='mvn clean install -DskipTests'
alias mi='mvn install'
alias mist='mvn install -DskipTests'
alias mt='mvn test'

alert_on_complete() {
  command_to_execute=$1
  eval "($command_to_execute && say done) || say failed"
}

# https://stackoverflow.com/a/38415982/4608329
complete -W "\`grep -oE '^[a-zA-Z0-9_.-]+:([^=]|$)' ?akefile | sed 's/[^a-zA-Z0-9_.-]*$//'\`" make

