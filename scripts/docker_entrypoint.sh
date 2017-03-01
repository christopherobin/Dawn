#!/usr/bin/env bash
#
# The entrypoint script is what docker will use
# to set the environment before it is used. In this case,
# we:
#
#   1. Ensure that all required environments are present
#   2. That the project contains a ./dawn folder
#   3. Optionally invite the user to create an environment folder
#      if it does not exist
#   4. Set up additional environment variables and create some configuration
#      files dynamically
#   5. Run the requested command, or open a shell if no command were given
#

# The project name is mostly used for informational purposes,
# but users may want to use this value to determine how
# their tools (Ansible, Terraform, etc) should run.
if
  [ "${DAWN_PROJECT_NAME}" == "" ]
then
  echo "The DAWN_PROJECT_NAME environment variable is not set; quitting."
  exit 1
fi

# We need to know which environment files to use;
# If the DAWN_ENVIRONMENT shell environment variable
# is not set, there is nothing else we can do.
if
  [ "${DAWN_ENVIRONMENT}" == "" ]
then
  echo "The DAWN_ENVIRONMENT environment variable is not set; quitting."
  exit 1
fi

# Go to the scripts folder
pushd /dawn/scripts/ > /dev/null

# Store the command we have received, and create
# a variable holding the path to the environment files
# in the project
export COMMAND="${@}"
export DAWN_PROJECT_FILES_PATH="/dawn/project/dawn"
export DAWN_PROJECT_CONFIG_FILE_PATH="${DAWN_PROJECT_FILES_PATH}/dawn.yml"
export DAWN_ENVIRONMENT_FILES_PATH="${DAWN_PROJECT_FILES_PATH}/${DAWN_ENVIRONMENT}"
export PS1="${DAWN_PROJECT_NAME} (${DAWN_ENVIRONMENT}):\w$ "

# We make sure that the base directory structure is present,
# and that a configuration file is indeed present.
if
  [ ! -f "${DAWN_PROJECT_CONFIG_FILE_PATH}" ]
then
  echo "Your project does not appear to have been initialized;"
  echo "There should be a ./dawn folder at the top-level of your project,"
  echo "and a ./dawn/dawn.yml file needs to be present."
  echo ""
  echo "You may create these files manually, but you should consider"
  echo "using the dawn binary for you platform instead".
  exit 1
fi

# If ./dawn/${environment_name} does not exist,
# we invite the user to create it
if
  [ ! -d "${DAWN_ENVIRONMENT_FILES_PATH}" ]
then
  source ./create_environment.sh
fi

# Once all of this has been done, we set up
# the local environment (environment variables,
# dynamically generated files, etc) and run
# the requested command
source ./setup_environment.sh
popd > /dev/null

# We finally downgrade the user and run the
# command. The reason for this is twofold:
#
#    1. Avoid unintentional changes to files put on the container.
#    2. (Windows) file permissions for ALL mounted files
#       is 0755; this means that running as root in the container
#       and trying to ssh to a remote server using an ssh key on the
#       mounted file system will result in "bad permission" error.
#
# Note that create.sh and run.sh do run as root; only the user's
# shell is downgraded to the dawn user.
#
# Ref: https://github.com/docker/docker/issues/27685#issuecomment-256648694
#
pushd ${DAWN_ENVIRONMENT_FILES_PATH} > /dev/null
sudo -u dawn ${COMMAND}
popd > /dev/null
