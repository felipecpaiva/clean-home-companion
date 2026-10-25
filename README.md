# Clean Home Companion

Free helper for Clean Home (the TV launcher, coming to Google Play). It does the small one-time jobs a TV will not let an app do alone. You can read every command it runs, right here.

Status: early. The computer script works. The phone app is planned.

## What it can do
| Job | Why | Command |
| --- | --- | --- |
| Give Clean Home access to Watch Next | Turns on the "Continue Watching" cards. A TV shows no permission box, so this is done from outside. | `watchnext` |
| Switch the Home button helper on | Makes the Home button open Clean Home. | `helper` |
| Remove clutter | Turns off telemetry, ad services and unused preloaded apps. Nothing is uninstalled. | `debloat` |
| Undo | Turns back on only what this tool turned off. | `restore` |
| Look first | Read only report of your TV. | `status` |

## What it will never do
- Uninstall anything. It only uses `pm disable-user`, which can always be undone.
- Touch Google's home screen (`launcherx`) or the setup wizard (`setupwraith`). Disabling those breaks casting and can trap the TV on a recovery screen. They are not in the list, and a built-in block refuses them even if you add them.
- Touch core Android packages (permissions, installer, system UI, providers).
- Touch Google ambient mode (`dreamx`, `backdrop`): that is the idle screen that shows your Google Photos album.
- Change anything on a dry run. `debloat` only shows a plan until you add `--apply`.

If Home shows a recovery or setup screen after a step, the script turns everything it changed back on and stops.

## Computer (Linux, macOS, Windows with Git Bash or WSL)
1. Install `adb` (Android platform-tools).
2. On the TV: Settings, System, About, press OK on Build seven times. Then Settings, System, Developer options, turn on Wireless debugging.
3. Pair once: choose "Pair device with pairing code" on the TV, then `adb pair <ip>:<pairing port> <code>` and `adb connect <ip>:<port>` (the main port, shown on the Wireless debugging screen).
4. Run:
```
export TV=<ip>:<port>
./scripts/clean-home-setup.sh status
./scripts/clean-home-setup.sh watchnext
./scripts/clean-home-setup.sh helper
./scripts/clean-home-setup.sh debloat           # shows the plan
./scripts/clean-home-setup.sh debloat --apply   # does it
./scripts/clean-home-setup.sh restore           # undo
```
5. When done, turn Wireless debugging off on the TV.

Do it by hand instead: `adb shell pm grant com.cleanhome.tv android.permission.READ_TV_LISTINGS`.

## Tested on
Chromecast with Google TV 4K (`sabrina`), Google TV 14. Other TVs: the list is made for this one. Use `status` and the dry run first. A Windows PowerShell version and the phone app are not written yet.

## Licence
MIT. See `LICENSE` and `NOTICE.md`.
