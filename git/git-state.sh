#!/bin/bash
# Print state of current branch in terms of how far ahead and behind
# it is of the upstream branch.
#
# Intended to implement a git command.
# Kudos: http://blog.santosvelasco.com/2012/06/14/extending-git-add-a-custom-command/

# Get current branch
# Kudos: http://stackoverflow.com/a/12142066/197789
local=$(git rev-parse --abbrev-ref HEAD)
# And it's upstream branch
# Kudos: http://stackoverflow.com/a/9753364/197789
remote=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})

tempfile=$(mktemp ${0}.${$}.XXXX)

# Kudos: http://stackoverflow.com/a/7774433/197789
git rev-list --left-right ${local}...${remote} -- 2>/dev/null >${tempfile}
LEFT_AHEAD=$(grep -c '^<' ${tempfile})
RIGHT_AHEAD=$(grep -c '^>' ${tempfile})
rm -f ${tempfile}
echo "$local (ahead $LEFT_AHEAD) | (behind $RIGHT_AHEAD) $remote"
exit 0
