#!/bin/sh
#
# Install my scripts
#

target_dir=${HOME}/bin

set -e  # Exit on error
set -u  # Uninitialized variables are errors

if test ! -d ${target_dir} ; then
    echo "Creating ${target_dir}"
    mkdir -p ${target_dir}
fi

# mindepth to ignore top-level directory
_find="find . -mindepth 2"

scripts="\
$(${_find} -name \*.py) \
$(${_find} -name \*.pl) \
$(${_find} -name \*.sh) \
"

for script in ${scripts} ; do
    base=$(basename ${script%.*})
    target=${target_dir}/${base}
    if test ! -e ${target} -o ${script} -nt ${target} ; then
	echo "Installing ${script} to ${target}"
	install -m 755 ${script} ${target}
    fi
done

exit 0
