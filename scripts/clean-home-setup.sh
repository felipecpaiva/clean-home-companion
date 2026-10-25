#!/usr/bin/env bash
# Clean Home setup over wireless debugging. Changes nothing unless you say so (debloat is a dry run until --apply).
# Usage: TV=<ip:port> ./clean-home-setup.sh <status|watchnext|helper|debloat|restore>
#   status    read only: model, Android, Home, disabled packages, Clean Home state
#   watchnext grant Clean Home access to Watch Next (READ_TV_LISTINGS)
#   helper    switch the Home button helper on
#   debloat   show the plan; with --apply, disable the safe list one package at a time, checking Home after each
#   restore   undo what debloat --apply did (leaves alone what was already off before)
# The TV: Settings > System > Developer options > Wireless debugging. Pair once: adb pair <ip:pairport> <code>, then adb connect <ip:port>.
set -u
P=com.cleanhome.tv
SVC="$P/$P.data.HomeKeyService"
HERE="$(cd "$(dirname "$0")" && pwd)"
LIST="${LIST:-$HERE/debloat-safe.txt}"
: "${TV:?set TV=<ip:port> (adb devices -l shows it)}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/clean-home-companion/${TV//[:\/]/_}"
mkdir -p "$STATE"
a() { adb -s "$TV" "$@"; }
sh() { adb -s "$TV" shell "$@" </dev/null | tr -d "\r"; }
die() { echo "STOP: $*" >&2; exit 1; }
# Never touch these, whatever a list says.
NEVER='^(android|com\.android\.(systemui|shell|phone|settings|tv\.settings|permissioncontroller|packageinstaller|providers\..*|ext\.services|ext\.shared|modulemetadata)|com\.google\.android\.(permissioncontroller|packageinstaller|ext\.services|ext\.shared|modulemetadata|overlay\.modules.*|apps\.tv\.launcherx|apps\.tv\.dreamx|backdrop|tvlauncher|tungsten\.setupwraith|gms|gsf|vending|katniss|apps\.mediashell|tv\.remote\.service|inputmethod\.latin)|com\.cleanhome\.tv)$'

home_ok() {  # Home must not be a recovery or setup screen
  local f; f=$(sh dumpsys activity activities | grep -m1 mFocusedApp)
  case "$f" in *RecoveryActivity*|*setupwraith*) return 1;; esac; return 0
}
need_device() { [ "$(a get-state 2>/dev/null)" = device ] || die "cannot reach $TV. Check Wireless debugging is on and run: adb connect $TV"; }

cmd_status() {
  echo "model:    $(sh getprop ro.product.model) ($(sh getprop ro.product.device))"
  echo "android:  $(sh getprop ro.build.version.release)  build $(sh getprop ro.build.display.id)"
  echo "home:     $(sh cmd role get-role-holders --user 0 android.app.role.HOME | tr '\n' ' ')"
  echo "focused:  $(sh dumpsys activity activities | grep -m1 mFocusedApp | sed 's/^ *//')"
  echo "disabled: $(sh pm list packages -d | wc -l) packages"
  if sh pm list packages | grep -q "package:$P$"; then
    echo "clean home: installed, $(sh dumpsys package $P | grep -m1 versionName | sed 's/^ *//')"
    sh dumpsys package $P | grep -q "READ_TV_LISTINGS: granted=true" && echo "watch next access: granted" || echo "watch next access: NOT granted (run: watchnext)"
    sh settings get secure enabled_accessibility_services | grep -q "$P" && echo "home helper: on" || echo "home helper: OFF (run: helper)"
  else echo "clean home: NOT installed"; fi
}

cmd_watchnext() {
  sh pm list packages | grep -q "package:$P$" || die "install Clean Home first"
  sh pm grant $P android.permission.READ_TV_LISTINGS
  sh dumpsys package $P | grep -q "READ_TV_LISTINGS: granted=true" && echo "done: Watch Next access granted. Turn it on in Clean Home: Settings > Watch Next." || die "grant did not take"
}

cmd_helper() {
  sh pm list packages | grep -q "package:$P$" || die "install Clean Home first"
  local cur; cur=$(sh settings get secure enabled_accessibility_services); [ "$cur" = null ] && cur=""
  case ":$cur:" in *":$SVC:"*) echo "already on";; *)
    sh settings put secure enabled_accessibility_services "${cur:+$cur:}$SVC"; sh settings put secure accessibility_enabled 1;; esac
  sh settings get secure enabled_accessibility_services | grep -q "$P" && echo "done: Home helper is on" || die "could not switch it on"
}

cmd_debloat() {
  local apply=0; [ "${1:-}" = --apply ] && apply=1
  [ -f "$STATE/before-disabled.txt" ] || { sh pm list packages -d | sort > "$STATE/before-disabled.txt"; sh pm list packages | sort > "$STATE/before-packages.txt"; echo "baseline saved in $STATE"; }
  home_ok || die "Home already shows a recovery screen. Run: adb -s $TV shell pm enable --user 0 com.google.android.apps.tv.launcherx"
  local todo=() p
  while read -r p; do
    p=${p%%#*}; p=${p//[[:space:]]/}; [ -n "$p" ] || continue
    [[ $p =~ $NEVER ]] && die "the list holds a protected package: $p"
    sh pm list packages | grep -q "package:$p$" || { echo "skip (not on this TV): $p"; continue; }
    grep -q "package:$p$" "$STATE/before-disabled.txt" && { echo "skip (already off): $p"; continue; }
    todo+=("$p")
  done < "$LIST"
  echo "to disable: ${#todo[@]}"; printf '  %s\n' "${todo[@]}"
  [ $apply = 1 ] || { echo "dry run. Add --apply to do it."; return; }
  for p in "${todo[@]}"; do
    if sh pm disable-user --user 0 "$p" | grep -q "new state: disabled-user"; then
      echo "$p" >> "$STATE/applied.txt"; echo "off: $p"
    else echo "refused by the TV, left alone: $p"; fi
    home_ok || { echo "Home changed after $p. Undoing everything."; cmd_restore; die "stopped; nothing left disabled by this tool"; }
  done
  echo "done. Cast from a phone once to check casting still works. Then turn Wireless debugging off on the TV."
}

cmd_restore() {
  [ -f "$STATE/applied.txt" ] || { echo "nothing to restore for $TV"; return; }
  local p; while read -r p; do sh pm enable --user 0 "$p" >/dev/null && echo "on again: $p"; done < <(sort -u "$STATE/applied.txt")
  : > "$STATE/applied.txt"
}

need_device
case "${1:-}" in
  status) cmd_status;; watchnext) cmd_watchnext;; helper) cmd_helper;;
  debloat) shift; cmd_debloat "${1:-}";; restore) cmd_restore;;
  *) sed -n '2,10p' "$0"; exit 2;;
esac
