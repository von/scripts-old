#!/bin/sh
######################################################################

usage() {
  cat 1>&2 <<EOF
Usage: $0 <cmd>

Commands are:
  pcmcia-eject
  pcmcia-insert
  standby
  suspend
EOF
}

pcmcia-eject() {
  # Shut down network first to avoid hanging pcmcia code
  sudo /etc/pcmcia/network stop eth0
  sudo /sbin/cardctl eject
}

pcmcia-insert() {
  sudo /sbin/cardctl insert
}

suspend() {
  pcmcia-eject
  sudo apm -s
}

standby() {
  sudo apm -S
}

######################################################################

cmd=$1

if [ "X${cmd}" = "X" ]; then
  usage
  exit 1
fi

case ${cmd} in
  pcmcia-eject)
    pcmcia-eject
    ;;

  pcmcia-insert)
    pcmcia-insert
    ;;

  standby)
    standby
    ;;

  suspend)
    suspend
    ;;

  *)
    echo "Unknown command: ${cmd}"
    usage
    exit 1
    ;;
esac

exit 0
