#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

! grep -Fq '${USER}' "$ROOT/bin/omarchy-sudo-passwordless" ||
  fail "passwordless sudo does not interpolate USER into sudoers"

# A bare id -nG reports this session's groups, fixed at login, so --configured
# must name the euid's account to see a change made since.
stub_dir=$(mktemp -d)
trap 'rm -rf "$stub_dir"' EXIT
cat >"$stub_dir/id" <<'STUB'
#!/bin/bash
case "$*" in
  -un) echo alice ;;
  "-nG alice") echo "alice wheel docker" ;;
  *) echo "alice wheel" ;;
esac
STUB
chmod +x "$stub_dir/id"
if USER=nobody PATH="$stub_dir:$PATH" "$ROOT/bin/omarchy-sudo-docker" --configured; then
  fail "sudoless Docker --configured reads the euid account's configured groups"
fi

for cmd in \
  "$ROOT/bin/omarchy-setup-security-sudoless-docker" \
  "$ROOT/bin/omarchy-remove-security-sudoless-docker" \
  "$ROOT/bin/omarchy-dev-install-ydoo" \
  "$ROOT/bin/omarchy-install-service-tailscale" \
  "$ROOT/bin/omarchy-install-gaming-xbox-controllers" \
  "$ROOT/bin/omarchy-install-service-nordvpn"
do
  grep -Fq 'user=$(id -un)' "$cmd" ||
    fail "$(basename "$cmd") takes the username from id -un"
  ! grep -Fq '"$USER"' "$cmd" ||
    fail "$(basename "$cmd") does not pass USER to a privileged command"
done

grep -Fq 'fprintd-enroll "$(id -un)"' "$ROOT/bin/omarchy-setup-security-fingerprint" ||
  fail "fingerprint enroll uses id -un"

pass "privileged commands take the username from the euid, not USER"
