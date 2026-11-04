# Desktop upgrade validation — 2026-11-04

Runtime changes have been applied; repository changes are ready for review and
commit by the user. The installer dry-run reports no remaining changes or local
conflicts. Original application windows and monitor geometry were preserved.

| Requirement | Evidence |
| --- | --- |
| Bar icons | Actual bar inspected; executor paths use the real HOME; both profiles share nonempty workspace role icons. |
| Bluetooth | Centered popup, paired rows and actual scan start/stop; power preserved on open. Forget confirmation and BlueZ RemoveDevice callback tested in an isolated fixture; API verified on the real adapter. Personal pairings retained. |
| Bind Saver | Real GTK capture and SUPER requirement; saved shortcut executed by the main sxhkd, then edited/deleted. Signal-reload race reproduced and fixed; same daemon stayed alive across consecutive reloads. |
| Animations | Workspace frames inspected; two temporary OS terminals opened/swapped; Kitty tabs created/switched/reordered and split. Temporary windows removed. |
| Calendar | Real temporary event created/edited/deleted; event dot and Today verified in the open Eww calendar. Editor appearance inspected. |
| Control center | Repeated mouse clicks without closing for Keep awake, DND, power and Wi-Fi. Real audio/mic toggles; menu routes opened/cancelled. Notification clear uses an isolated history fixture. Original service states restored. |
| Lock | Automated fake-locker tests; user physically locked/unlocked and confirmed no blackout or flash of the desktop. |
| Backups | Transactional installer backups remain under ~/.local/state/rice/backups/. No Git commit or push performed. |

`python -B -m unittest discover -s tests -q`: **73 tests passed**.
`python -B scripts/check.py`: **57 shell files, 118 hotkeys, 10 templates**.
Shellcheck was unavailable and explicitly skipped.

Local benchmark: workspace event-render median fell from 55.65 ms to 1.53 ms by
keeping the state reader warm and using one bspwm snapshot. This measures that
specific rendering path, not overall desktop speed. Three verified power-cycle
actions measured approximately 303, 493 and 580 ms with the D-Bus backend.

Recordings, runtime-state snapshots and detailed results are private local audit
artifacts in ~/.local/state/rice/changes/desktop-upgrade-20261104T185116Z/.
Event and custom-bind test records were removed after verification. Existing
personal history and pairings were not deleted for testing.
