#!/bin/sh
#
# Wrapper around pbpaste to handle running in tmux on MaxOSX
# and using reattach-to-user-namespace.
#
# See:
# https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard
# http://robots.thoughtbot.com/post/19398560514/how-to-copy-and-paste-with-tmux-on-mac-os-x
# http://unix.stackexchange.com/a/32451

_pbpaste=/usr/bin/pbpaste  # XXX Determine dynamically

if test -n "${TMUX}" -a $(uname) = "Darwin" ; then
    exec reattach-to-user-namespace ${_pbpaste} "$@"
else
    exec ${_pbpaste} "$@"
fi
