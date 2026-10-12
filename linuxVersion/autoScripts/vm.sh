#!/bin/bash
set -euo pipefail
virsh() { command virsh -c qemu:///system "$@"; }
vm=$2
case $1 in
  open)
    virsh start "$vm" >/dev/null
    setsid -f virt-viewer -c qemu:///system --kiosk --kiosk-quit on-disconnect "$vm" >/dev/null 2>&1
    until virsh qemu-agent-command "$vm" '{"execute":"guest-ping"}' >/dev/null 2>&1; do sleep 2; done
    dir=$(mktemp -d)
    trap 'rm -rf "$dir"' EXIT
    shot() { virsh screenshot "$vm" "$dir/$1" >/dev/null; sleep 3; }
    until shot a && shot b && shot c && cmp -s "$dir/a" "$dir/b" && cmp -s "$dir/b" "$dir/c"; do :; done
    ;;
  close)
    virsh shutdown "$vm" >/dev/null
    until [ "$(virsh domstate "$vm")" = "shut off" ]; do sleep 2; done
    ;;
  *) exit 2;;
esac
