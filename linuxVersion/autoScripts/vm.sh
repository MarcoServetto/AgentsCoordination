#!/bin/bash
set -euo pipefail
virsh() { command virsh -c qemu:///system "$@"; }
[ $# -eq 2 ] || { echo "usage: vm.sh open|close <vm>" >&2; exit 2; }
vm=$2
virsh dominfo "$vm" >/dev/null
waitFor() {
  local what=$1 seconds=$2; shift 2
  local end=$((SECONDS + seconds))
  until "$@"; do
    [ $SECONDS -lt $end ] || { echo "vm.sh: $vm $what after $seconds s" >&2; exit 1; }
    sleep 2
  done
}
answers() { virsh qemu-agent-command "$vm" '{"execute":"guest-ping"}' >/dev/null 2>&1; }
shot() { virsh screenshot "$vm" "$dir/$1" >/dev/null 2>&1; }
settled() {
  shot a; sleep 3; shot b; sleep 3; shot c
  cmp -s "$dir/a" "$dir/b" && cmp -s "$dir/b" "$dir/c"
}
off() { [ "$(virsh domstate "$vm")" = "shut off" ]; }
case $1 in
  open)
    others=$(virsh list --name | grep -v -x -e "" -e "$vm" || true)
    [ -z "$others" ] || { echo "vm.sh: $vm not opened, already running: $others" >&2; exit 1; }
    off && virsh start "$vm" >/dev/null
    pgrep -u "$USER" -f "^virt-viewer .* $vm\$" >/dev/null || setsid -f virt-viewer -c qemu:///system --kiosk --kiosk-quit on-disconnect "$vm" >/dev/null 2>&1
    dir=$(mktemp -d)
    trap 'rm -rf "$dir"' EXIT
    waitFor "does not answer the guest agent" 300 answers
    waitFor "has a screen that does not settle" 300 settled
    ;;
  close)
    off || virsh shutdown "$vm" >/dev/null
    waitFor "is not off" 180 off
    ;;
  *) echo "usage: vm.sh open|close <vm>" >&2; exit 2;;
esac
