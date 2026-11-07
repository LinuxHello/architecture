---
type: spike
subject: Extension point in KDE's Users settings module
artifact: spike
status: answered
owner: "@atterdag"
concepts: [plasma, kcm-users, settings, upstream]
tags: [spike, m0, upstream]
sources:
  - https://invent.kde.org/plasma/plasma-workspace/-/tree/v6.8.2/kcms/users
  - https://invent.kde.org/plasma/systemsettings/-/tree/v6.8.2
  - https://invent.kde.org/frameworks/kcmutils/-/tree/v6.31.0
  - https://bugs.kde.org/show_bug.cgi?id=454627
  - https://invent.kde.org/plasma/plasma-workspace/-/merge_requests/7353
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/10
---

# Spike: Extension point in KDE's Users settings module

## Question

Does KDE's Users settings module have an extension point for adding Face and PIN entries beside the fingerprint entry?

## Time box

Proposed: 2 working days. This pass is a source read only (under one day). No question was put to KDE.

## Method

Read the source at the tags below, cloned shallow into a scratch directory. Nothing was built, installed or run on the host.

| Project | Ref | Commit | Version |
| :-- | :-- | :-- | :-- |
| plasma-workspace (holds `kcms/users`) | tag `v6.8.2` | `30beb00` (`30beb0095873364c6b34ebcfd292ecafd4db7f61`, 2026-10-27) | 6.8.2 (`CMakeLists.txt`, line 4) |
| systemsettings (the host application) | tag `v6.8.2` | `f285845` (`f2858453a9b7fa402fba81d3cce528dba0349fc2`) | 6.8.2 |
| kcmutils (`kcmutils_add_qml_kcm`) | tag `v6.31.0` | `987a29d` (`987a29d90bc2f305bd833a9b4accdab1953be1a3`) | 6.31.0 |

v6.8.2 is the newest `v6.8.*` tag on `invent.kde.org/plasma/plasma-workspace` (tags listed with `git ls-remote --tags`); v6.31.0 is the newest kcmutils tag. Which kcmutils release Plasma 6.8.2 is built against was not checked.

```sh
git clone --depth 1 --branch v6.8.2 https://invent.kde.org/plasma/plasma-workspace.git
git clone --depth 1 --branch v6.8.2 https://invent.kde.org/plasma/systemsettings.git
git clone --depth 1 --branch v6.31.0 https://invent.kde.org/frameworks/kcmutils.git
git grep -n -i -E "fprint|Loader|createComponent|plugin" -- kcms/users      # in plasma-workspace
curl -sS "https://bugs.kde.org/rest/bug?product=systemsettings&component=kcm_users&short_desc=face&short_desc_type=allwordssubstr"
curl -sS "https://invent.kde.org/api/v4/projects/plasma%2Fplasma-workspace/merge_requests?search=howdy&state=all"
```

All commands: **tested**, as source reading and web-API queries from a Linux workstation (no hardware dependence). The upstream search used keywords (`howdy`, `face`, `face unlock`, `biometric`, `fingerprint`, `pam`, `users kcm`, `kcm_users`, `authentication`, `pluggable`) on bugs.kde.org (product `systemsettings`, component `kcm_users`) and on merge requests in `plasma-workspace`, `plasma-desktop` and `systemsettings`. Matching is on titles and descriptions only.

**Not done, so untested:** building `kcm_users` or running System Settings; a prototype KCM placed beside Users; running a Linux Hello KCM on Plasma 6.8; any question to KDE.

## Blocks

Decides between an upstream patch to plasma-workspace and the interim Linux Hello settings page. Blocks the settings UI (face and PIN enrolment entries).

## Evidence

Paths are relative to `kcms/users/src/` in plasma-workspace at `v6.8.2` unless stated.

1. **The module is in plasma-workspace, not plasma-desktop.** `kcms/users` does not exist in plasma-desktop `v6.8.2` (its `kcms/` has no `users` directory). plasma-desktop merge request 616, "[kcm/users] Move to plasma-workspace", merged 2021-10-29 (https://invent.kde.org/plasma/plasma-desktop/-/merge_requests/616). A patch goes to plasma-workspace.
2. **The fingerprint entry is one hard-wired button and one dialog.** In `ui/UserDetailsPage.qml` the button `fingerprintButton` (line 281) is visible only when `kcm.fingerprintModel.deviceFound` (line 285), reads "Configure Fingerprint Authentication…" (line 286) and opens `FingerprintDialog.qml` with `Qt.createComponent("FingerprintDialog.qml")` (line 298). A help label follows (lines 316–318). `FingerprintDialog.qml` is one of the module's own files; no `Loader`, plugin lookup or model of entries appears in `ui/` (the only `createComponent` calls open the module's own `PicturesSheet.qml`, `CropSheet.qml` and `FingerprintDialog.qml`: `UserDetailsPage.qml` lines 149 and 298, `PicturesSheet.qml` line 148).
3. **The fingerprint backend is one C++ model talking to fprintd.** `KCMUser` owns `FingerprintModel *m_fingerprintModel` (`kcm.h`, lines 20 and 26) and creates it in its constructor (`kcm.cpp`, line 42), then exposes it to QML as `kcm.fingerprintModel`. The model calls `net.reactivated.Fprint.Manager.GetDefaultDevice` on the system bus (`fingerprintmodel.cpp`, lines 11–16) and wraps the device in `FprintDevice` (`fprintdevice.cpp`, lines 11–15), which calls `Claim` (line 27), `EnrollStart`, `ListEnrolledFingers`, `DeleteEnrolledFinger` on `net.reactivated.Fprint.Device`. The ten fingers are a fixed list (`fingerprintmodel.h`, line 59). The D-Bus interfaces are compiled in from XML (`CMakeLists.txt`, lines 7–30). Nothing here is configurable by a third party: the service name, object path and interface are literals.
4. **Nothing is pluggable in the module.** `K_PLUGIN_CLASS_WITH_JSON(KCMUser, "kcm_users.json")` (`kcm.cpp`, line 31) makes the module itself a plugin, but it loads none. The QML files are compiled into the plugin as resources: `kcmutils_add_qml_kcm(kcm_users)` (`CMakeLists.txt`, line 32) globs the hard-coded `ui` folder into a `.qrc` (`KF6KCMUtilsMacros.cmake` in kcmutils `v6.31.0`, lines 168–172). A case-insensitive `grep` for `kplugin`, `Loader`, `KPackage`, `QPluginLoader` and `findPlugins` over `kcms/users/src` finds only the module's own `KPluginFactory` and `KPluginMetaData` use (`kcm.cpp`, lines 13 and 35); no plugin loading and no KPackage. QML types registered for outside use are only `UserModel`, `User`, `MaskMouseArea` and `FprintDevice` (enum access) (`kcm.cpp`, lines 48–54).
5. **The only outward-facing hook is a comment.** `ui/main.qml`, lines 84–87, says `switchBackToUser()` "can be used to pop KCM stack in downstream KCM". `main.qml` pushes `UserDetailsPage.qml` on the module's own page stack (lines 80, 90, 110, 143). It describes patches carried by distributions, not an extension API. No documentation of an extension point was found.
6. **KCMs register by metadata, which is the interim route.** `kcm_users.json` carries `KPlugin` (`Name`, `Icon`, `Description`, `FormFactors`), `X-KDE-Keywords` (it lists "fingerprint,biometric"), `"X-KDE-System-Settings-Parent-Category": "system-administration"` (line 174) and `"X-KDE-Weight": 40` (line 175). `kcmutils_add_qml_kcm` installs a plugin into `plasma/kcms/systemsettings` by default (`KF6KCMUtilsMacros.cmake`, lines 164–168) and generates a desktop file unless `DISABLE_DESKTOP_FILE_GENERATION` is passed (lines 156–171). System Settings finds modules with `KPluginMetaData::findPlugins` in `plasma/kcms`, `plasma/kcms/systemsettings` and `plasma/kcms/systemsettings_qwidgets` (`systemsettings` `app/kcmmetadatahelpers.h`, lines 114–117), keeps those whose form factor matches (lines 84–111), places each under the category named by `X-KDE-System-Settings-Parent-Category` (or the `-V2` key) and sorts by `X-KDE-Weight` (`app/SettingsBase.cpp`, lines 205–238). Category definitions are the `.desktop` files in `categories/`; `settings-system-administration.desktop` has `X-KDE-System-Settings-Category=system-administration`, the category Users is in. A third-party KCM can therefore appear beside Users with no change to System Settings.
7. **A second, lighter route exists: external modules.** `findExternalKCMModules` reads `.desktop` files from `plasma/systemsettings/externalmodules` in the generic data directories and turns each into a menu entry with `Name`, `Icon`, `Comment`, `X-KDE-Weight` and the parent category keys (`app/kcmmetadatahelpers.h`, lines 30–65). It launches an external application. It places an entry in the sidebar, not on the Users page.
8. **Upstream issue and merge requests.**
   - Bug 454627, "Add support for face unlock", product `systemsettings`, component `kcm_users`, status CONFIRMED, opened 2022-05-30 (https://bugs.kde.org/show_bug.cgi?id=454627). Comment 3 (2022-06-01, by a KDE developer) says "Aleix started working on this a while back but got stuck on some upstream issues IIRC"; the issues are not named. Comments on 2025-10-28 and 2026-08-06 ask whether the blocker is resolved; no answer is recorded in the bug as read on 2026-11-08.
   - No bug or merge request on pluggable authentication methods was found. Searches in the three repositories returned nothing for `howdy`, `face unlock` or `biometric`; `pluggable` in `kcm_users` bugs returned nothing.
   - plasma-workspace merge request 7353, "Expand the users KCM" (closed unmerged 2026-11-03), and open request 7360, "Add group management", extend account management (groups, expiry, sessions). They do not touch authentication methods (https://invent.kde.org/plasma/plasma-workspace/-/merge_requests/7353).
   - bugs.kde.org 485124, "[Users KCM] Warn when missing dependencies for login with fingerprint", CONFIRMED: shows how fingerprint-specific the page is; not about extension.
   - Related Fedora KDE SIG issue (https://pagure.io/fedora-kde/SIG/issue/169) argues Howdy support belongs in the Users KCM; read from a search snippet only, not opened.

## Answer

**No.** `kcm_users` at Plasma 6.8.2 has no extension point for authentication methods. The fingerprint entry is a fixed button and dialog backed by a C++ model that talks only to fprintd, compiled into the module. Face and PIN entries beside it need an upstream change.

Design consequences:

- **Interim: a separate Linux Hello settings page.** It is a KCM built with `kcmutils_add_qml_kcm`, with a `kcm_linuxhello.json` setting `"X-KDE-System-Settings-Parent-Category": "system-administration"` and an `X-KDE-Weight` close to Users' 40, so it sorts next to it and needs no change in KDE code. This matches the `Linux Hello Settings Module` component in `workspace.dsl` (line 51). Search keywords in the JSON (`face`, `pin`, `biometric`) make it findable. The lighter `externalmodules` desktop file (item 7) is a fallback if the KCM cannot be shipped. What it does not cover: the face and PIN entries are not on the Users page, and the user sees fingerprint under Users and Face and PIN elsewhere.
- **Smallest upstream change (described, not written, not reviewed by KDE).** Replace the hard-wired `fingerprintButton` and its help label in `UserDetailsPage.qml` with a `Repeater` over a list of authentication-method entries (`name`, `icon`, `description`, `visible`, and what to open). The fingerprint entry becomes the first item, produced by the existing `FingerprintModel`. A third party contributes an entry either as a QML component loaded with a `Loader` from a plugin found by `KPluginMetaData::findPlugins` in a new namespace, or, more cheaply, as a desktop file whose action launches its own KCM or dialog (the same idea as `externalmodules`). The second form keeps third-party code out of the `kcm_users` process. The patch touches `UserDetailsPage.qml`, `kcm.cpp`/`kcm.h` and the CMake file in plasma-workspace.
- **A question to KDE would be needed** (not asked here; no KDE channel was used): whether a method list on the Users page is acceptable to the Users KCM maintainers, and which form (plugin or desktop file). Also to ask on bug 454627 what upstream issue blocked the earlier face-unlock attempt. These go on the Plasma development channels and on that bug, by the maintainer.
- **Not covered by this note:** whether such a patch would be accepted; the lock screen and login screen, which are separate components; how the Users page text "Logging into the system with your fingerprint is not yet supported" (line 318) relates to PAM configuration, which is spike 0007's subject; whether the interim KCM shows correctly for another user than the logged-in one (the Users page passes a user name to fprintd, `UserDetailsPage.qml` line 295), which needs a run.
- **Follow-up for the architecture:** the settings container in `workspace.dsl` and the `Linux Hello Settings Module` component stay as drawn (an interim KCM). Record a decision (ADR) only if the upstream patch is adopted as a milestone.
