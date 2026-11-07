---
type: spike
subject: Third-party prompt in the Plasma login manager and kscreenlocker
artifact: spike
status: answered
owner: "@atterdag"
concepts: [plasma, sddm, plasma-login-manager, kscreenlocker, qml, dbus, ux]
tags: [spike, m0, upstream]
sources:
  - https://github.com/sddm/sddm/tree/633c1bf5c08d6c8e5b8435a70edb281b9f7b1550
  - https://invent.kde.org/plasma/kscreenlocker/-/tree/v6.8.2
  - https://invent.kde.org/plasma/plasma-workspace/-/tree/v6.8.2
  - https://invent.kde.org/plasma/plasma-desktop/-/tree/v6.8.2
  - https://invent.kde.org/plasma/libplasma/-/tree/v6.8.2
  - https://invent.kde.org/plasma/plasma-login-manager/-/tree/v6.8.2
  - https://invent.kde.org/plasma/kscreenlocker/-/tree/v6.6.6
  - https://github.com/systemd/systemd/tree/v259
  - https://github.com/LinuxHello/linux-hello/blob/main/crates/linuxhello-dbus/src/lib.rs
  - ../spikes/0007-pam-dbus-method-state.md
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/9
---

# Spike: Third-party prompt in the Plasma login manager and kscreenlocker

## Question

How do the Plasma login manager and kscreenlocker accept a third-party prompt component, and can one component look identical in both and in-session?

## Time box

Proposed: 2 working days. This pass is a **source read only**. No component was built and nothing was installed or run on a host.

## Method

Read upstream source at the current Plasma release and the SDDM development head, then for each surface established: how the prompt UI is loaded, what a third party can replace, what the UI is told about the PAM conversation, which user and bus the process has, and how QML could subscribe to D-Bus signals. Spike [0007](0007-pam-dbus-method-state.md) settled which bus each PAM context reaches; this note reuses its findings and does not repeat them.

| Project | Ref | Commit | Date |
| :-- | :-- | :-- | :-- |
| kscreenlocker | `v6.8.2` | `972baf4a25e08991c7c0451d983497eaf30cb0a8` | 2026-10-27 |
| plasma-workspace | `v6.8.2` | `30beb0095873364c6b34ebcfd292ecafd4db7f61` | 2026-10-27 |
| plasma-desktop | `v6.8.2` | `3a67a04b656bda45b2c175b5f12bb7e4222d5026` | 2026-10-27 |
| libplasma | `v6.8.2` | `6f6566e4ec44a432abdcdd4854cbed3582bcddd1` | 2026-10-27 |
| plasma-login-manager | `v6.8.2` | `e061af4085b1231042ca97f3e8bf3481b6cfa2e6` | 2026-10-27 |
| SDDM | `develop` head (`CMakeLists.txt` lines 10–13: 0.21.0; latest GitHub release `v0.21.0`) | `633c1bf5c08d6c8e5b8435a70edb281b9f7b1550` | 2026-10-20 |
| kscreenlocker (for comparison) | `v6.6.6`, the version read in spike 0007 | `b0d25d5f33297c90e2c3ae6563d7d9f7f7425942` | 2026-07-07 |
| systemd | `v259` | tag only | n/a |

`v6.8.2` is the newest tag of the current 6.8 series. The tags `v6.7.6` (2026-11-03) and `v6.6.7` also exist; they are bugfix releases of older series. File paths below are relative to the repository named in the row, and `file:line` is the line at that ref.

Commands: shallow `git clone --branch <tag>` of each repository, then `grep -n` and `sed -n` over the files named in Evidence. SDDM files `GreeterProxy.h`, `Greeter.cpp` and `PamBackend.cpp` were compared with the commit `4fe234b` that spike 0007 read: they are identical; `GreeterApp.cpp` and `Display.cpp` differ only in lines unrelated to theme loading and prompt handling.

All of the above: **tested** as source reading. **Nothing was run.** No greeter, theme, lock screen or QML component was started, so every runtime statement below is **untested**.

## Blocks

The login manager, lock screen and in-session prompts must look identical and show the active method (UX1, UX2, UX5 in [08 Crosscutting concepts](../arc42/08-crosscutting-concepts.md)). Blocks the Plasma prompt component and UX2.

## Evidence

### Login manager: SDDM

1. **A third party supplies a whole theme, not a component.** The greeter reads `<theme>/metadata.desktop` and a config file (`src/greeter/GreeterApp.cpp:95-117`). `src/common/ThemeMetadata.cpp:61-64` reads four keys: `MainScript` (default `Main.qml`), `ConfigFile`, `TranslationsDirectory`, `QtVersion`. No key names a base theme, a parent or an extra component, and I found no inheritance in the sources read. The theme is chosen by `[Theme] Current` under `ThemeDir` (`src/common/Configuration.h:53-54`) and passed to the greeter as `--theme` (`src/daemon/Greeter.cpp:121-122`). The greeter loads `MainScript` as the source of one `QQuickView` per screen (`GreeterApp.cpp:197-223`); on a QML error it falls back to the embedded theme (`GreeterApp.cpp:205-219`).
2. **Plasma's own theme is a copy-or-replace unit.** The Breeze SDDM theme lives in plasma-desktop, not plasma-workspace: `sddm-theme/` (`metadata.desktop:111-121`: `Type=sddm-theme`, `MainScript=Main.qml`, `QtVersion=6`), installed to `<datadir>/sddm/themes/breeze` when `INSTALL_SDDM_THEME` is set (`plasma-desktop/CMakeLists.txt:19, 259-274`). plasma-workspace 6.8.2 has no `sddm-theme` directory and its `lookandfeel/` has none for the login screen. Linux Hello can add the component only by shipping a theme of its own (a fork of Breeze with the component inside) or by patching Breeze upstream.
3. **A theme may import any QML module on the greeter's import path.** The greeter adds `IMPORTS_INSTALL_DIR` (`GreeterApp.cpp:170`, `src/common/Constants.h.in:27`, `CMakeLists.txt:180`) and the daemon passes `QML2_IMPORT_PATH`, `QT_PLUGIN_PATH` and `LD_LIBRARY_PATH` from its own environment to the greeter (`Greeter.cpp:197-205`). Breeze already imports plasma-workspace modules: `org.kde.plasma.workspace.keyboardlayout`, `org.kde.plasma.private.keyboardindicator` and `org.kde.breeze.components` (`sddm-theme/Main.qml:14-18`; module definitions in plasma-workspace `components/keyboardlayout/CMakeLists.txt:1`, `applets/keyboardindicator/plugin/CMakeLists.txt:4`, `lookandfeel/CMakeLists.txt:5`). A Qt 6 theme runs in `sddm-greeter-qt6` (`Greeter.cpp:83-96`).
4. **The greeter is told nothing about methods.** The theme gets the context objects `sessionModel`, `screenModel`, `userModel`, `config`, `sddm` and `keyboard` (`GreeterApp.cpp:187-193`). `sddm` offers `login(user, password, sessionIndex)` and the signals `loginFailed`, `loginSucceeded`, `informationMessage(QString)` (`src/greeter/GreeterProxy.h:65, 74, 83-84`; `docs/THEMING.md:48-54`). In the daemon, a PAM request with one prompt is answered with the stored password, one with two prompts with the user name and the password; other shapes are not answered (`src/daemon/Display.cpp:551-560`). PAM info and error messages reach the theme only as text through `informationMessage` (`Display.cpp:521-537`; `PamBackend.cpp:312-317`). A PAM conversation is therefore text only here, as the [crosscutting concepts](../arc42/08-crosscutting-concepts.md) already assume, and the method indicator needs the D-Bus side channel.
5. **The greeter is a separate user.** `Greeter.cpp:232` starts it as `sddm` through `sddm-helper`, with PAM service `sddm-greeter` (`src/helper/backend/PamBackend.cpp:222-223`). Its environment is built from a whitelist (`Greeter.cpp:194-226`); `DBUS_SESSION_BUS_ADDRESS` is not among the variables set, and the string does not occur in `src/` at all. The PAM environment is merged into the session environment (`PamBackend.cpp:278`), and `pam_systemd` sets `DBUS_SESSION_BUS_ADDRESS` only from `pam_sm_open_session` (`systemd v259 src/login/pam_systemd.c:1491, 1725`). The repository ships no PAM service file for `sddm-greeter` (searched `services/`, `data/`, `src/`); the file comes from the distribution. **Whether the greeter has a session bus is therefore not established here.** The system bus admits every uid by default (spike 0007, evidence 6–7).

### Login manager: Plasma Login Manager (new in the 6.8 series)

6. plasma-login-manager is a fork of SDDM with its own greeter (`README.md:3`). The greeter loads `qrc:/qt/qml/org/kde/plasma/login/Main.qml` (`src/frontend/greeter/main.cpp:82`) from a QML module compiled into `plasma-login-greeter` (`src/frontend/greeter/CMakeLists.txt:30-37`). I found no theme directory, no `--theme` option and no import of a third-party module point. The proxy keeps SDDM's shape: `login(...)` and `informationMessage`, `loginFailed`, `loginSucceeded` (`src/frontend/greeter/backend/GreeterProxy.h:43, 51-56`), and the daemon answers one or two prompts the same way (`src/daemon/Display.cpp:358-366`). It runs the greeter as user `plasmalogin` (`src/daemon/Greeter.cpp:117`) from a systemd unit (`src/frontend/greeter/plasma-login.service.in`, `plasma-login-wayland.target`). Not established: whether any distribution ships it as the default, and its PAM service files and bus setup. Its README advises against installing the development version on real hardware.

### Lock screen: kscreenlocker

7. **The lock screen is part of the shell package, not of a look-and-feel package.** `UnlockApp::initialize` calls `setShell(defaultShell())` (`kscreenlocker/greeter/greeterapp.cpp:194`). `defaultShell()` reads `ShellPackage` in the `[Shell]` group of `plasmashellrc`, default `org.kde.plasma.desktop`, overridable by `PLASMA_DEFAULT_SHELL` (`settings/shell_integration.cpp:35-44`). `setShell` loads that `Plasma/Shell` package and uses its `lockscreenmainscript` (`greeterapp.cpp:502-516`), defined as `lockscreen/LockScreen.qml` (`libplasma src/plasma/packagestructure/shell/shellpackage.cpp:63-64`). plasma-desktop's `desktoppackage/metadata.json:2` declares `"KPackageStructure": "Plasma/Shell"` and holds `contents/lockscreen/LockScreen.qml`, `LockScreenUi.qml` and `MainBlock.qml`. The look-and-feel packages in plasma-workspace (`lookandfeel/org.kde.breeze/metadata.json:2`, `"Plasma/LookAndFeel"`) contain `defaults`, `layouts`, `previews` and `splash`, and no lock-screen files; `grep -i "lookandfeel\|look-and-feel"` over the `.cpp`, `.h`, `.qml` and `.txt` files of kscreenlocker finds nothing.
8. **`ShellPackage` also selects the Plasma shell itself.** `ShellCorona::defaultShell()` reads the same key and default (plasma-workspace `shell/shellcorona.cpp:2988-2998`). A replacement lock screen packaged as a shell therefore replaces `plasmashell`'s shell package too, unless it is a copy of `org.kde.plasma.desktop` with only the lock screen changed. The package must declare `X-Plasma-APIVersion` 2 or higher, otherwise kscreenlocker falls back to `org.kde.plasma.desktop` (`greeterapp.cpp:82-98, 511-514`). If the lock-screen QML fails to load, a built-in `qrc:/fallbacktheme/LockScreen.qml` is used so the user is not locked out (`greeterapp.cpp:363-377`).
9. **No extension slot in the stock lock screen.** `LockScreenUi.qml` has a fixed layout; its only dynamic part is the method selector built from `ScreenLocker.AuthenticatorModel` (`LockScreenUi.qml:333-362`; roles `type`, `iconName`, `passwordField`, `expectingPrompt`, `tooltip`, `showPrompt`, `functional`). The model has five fixed entries: Password, Smartcard, Fingerprint, Face, Universal 2 Factor (`kscreenlocker greeter/pamauthenticatormodel.cpp:45-84`; enum at `pamauthenticators.h:50-56`). Fingerprint, face and the others appear only if enabled per user in `kscreenlockerrc` `[Authenticators]` (`pamauthenticatormodel.cpp:55-83`) and not disabled at build time. The PAM service names are CMake cache values: `kde`, `kde-fingerprint`, `kde-smartcard`, `kde-face`, `kde-u2f` (`greeter/worker/CMakeLists.txt:6-25`; mapping in `greeter/pamauthenticators.cpp:178-191`). The QML sees the active service's text through `authenticator.prompt`, `promptForSecret`, `infoMessage` and `errorMessage` (`pamauthenticators.h:26-30`; `LockScreenUi.qml:91-105`; `MainBlock.qml:145-148`) and nothing else about the method.
10. **PAM runs in a worker process, as the user.** Each `PamAuthenticator` starts `kscreenlocker_worker` with the service and user name (`greeter/pamauthenticator.cpp:304-309`), which calls `pam_start` and `pam_authenticate` (`greeter/worker/main.cpp:265, 311`) and talks to the greeter over a private peer-to-peer D-Bus connection (`pamauthenticator.cpp:301-302, 313-319`; `worker/main.cpp:387`). The greeter makes `prctl` calls for the dumpable flag and the parent-death signal only; I found no seccomp filter or other sandbox in `greeter/` (`greeter/main.cpp:60-63`; `greeter/worker/prctls.h:32, 42`). It is the user's own process in the user's session, as spike 0007 found at 6.6.6.
11. **Version drift matters for the target distribution.** At `v6.6.6`, the version spike 0007 read, `greeter/CMakeLists.txt:69-87` defines only the services `kde`, `kde-fingerprint` and `kde-smartcard`; `greeter/worker/CMakeLists.txt` and `greeter/pamauthenticatormodel.cpp` return 404, so there is no worker process, no model and no face or U2F kind. Loading of the lock screen through `lockscreenmainscript` is the same (`greeter/greeterapp.cpp:180, 575` at `v6.6.6`; `settings/shell_integration.cpp:39-40`). The 6.8.2 findings on items 9 and 10 therefore do not hold on a distribution that ships 6.6.x.

### Reuse across surfaces, and subscribing to the Agent

12. **There is precedent for one QML module used by login manager and lock screen.** `org.kde.breeze.components` is imported by both the SDDM theme (`sddm-theme/Login.qml:1`, `Main.qml:18`) and the lock screen (`desktoppackage/contents/lockscreen/LockScreenUi.qml:26`, `MainBlock.qml:17`), and by the Plasma Login greeter (`plasma-login-manager src/frontend/greeter/qml/Login.qml:8`). It is installed as a system QML module from plasma-workspace (`lookandfeel/CMakeLists.txt:5-17`). A Linux Hello module installed the same way, in the system QML directory (readable by the `sddm` user, unlike a home directory), is importable by all three. Each host still needs its own page around the module (the SDDM theme or shell package that embeds it).
13. **QML can listen to D-Bus signals with an existing Plasma module.** plasma-workspace ships `org.kde.plasma.workspace.dbus` (`components/dbus/CMakeLists.txt:4`) with `SignalWatcher`, `Properties` and `ServiceWatcher`. `SignalWatcher` takes `service`, `path` and `iface`, a `busType` of `Session`, `System` or a bus address string, and calls a QML function named `dbus<SignalName>` (`components/dbus/dbussignalwatcher.h:22-41, 64`; `dbusservicewatcher.h:14-21`). It subscribes to all signals of the interface (`dbussignalwatcher.cpp:208-214, 223`). I found no Qt-provided D-Bus type for QML in the sources read; a Linux Hello C++ QML plugin around `QDBusConnection` is the alternative.
14. **What the Agent API offers today.** `crates/linuxhello-dbus/src/lib.rs` defines the bus name, object path and interface (`io.github.LinuxHello.Agent1`, lines 14–19) and nothing else: no signal or method signature, and no per-prompt identifier. [`workspace.dsl`](../workspace.dsl) line 18 lists the planned signals `MethodsAvailable`, `ActiveMethod`, `State`, `Result` "per prompt". ADR-0012 fixes the names but not the bus (spike 0007).

| Surface | Prompt UI loaded from | Third-party hook found | Told about methods | Runs as | Buses (spike 0007 and items 5, 10) |
| :-- | :-- | :-- | :-- | :-- | :-- |
| SDDM | Theme directory, `MainScript` | Whole theme only; import any installed QML module | Text via `informationMessage` | `sddm` | System yes; session unestablished |
| Plasma Login Manager | QML compiled into the greeter | None found | Text via `informationMessage` | `plasmalogin` | Not read |
| kscreenlocker 6.8.2 | `lockscreen/LockScreen.qml` of the `ShellPackage` shell | Whole shell package, or PAM service names; fixed method list | Text of the active service | The user | System yes; session yes |
| kscreenlocker 6.6.6 | Same | Same, without face and U2F kinds | Text of the active service | The user | System yes; session yes |
| In-session Prompt UI | Linux Hello's own process (`workspace.dsl:49`) | Not applicable | Not applicable | The user | System yes; session yes |

**Not done, so untested:** loading a stub theme in `sddm-greeter-qt6` (`--test-mode`); a Shell package fork with a changed `LockScreen.qml`; importing a module that uses `SignalWatcher` in the greeter as `sddm` and as `plasmalogin`; the PAM files and session bus of the `sddm-greeter` service on Ubuntu 26.04; the Plasma Login Manager end to end; the 6.6.x lock screen on the target distribution; whether a system-bus `SignalWatcher` receives signals the Agent addresses to the user (rather than broadcasts); QML module versioning across Plasma updates; how many seconds the greeter takes to load a theme that imports a D-Bus module. Plasma Login Manager's PAM stack and how a distribution selects it were not read.

## Answer

**Partly.**

- **Neither login manager nor lock screen has a slot for a prompt component.** SDDM accepts a whole theme, the Plasma Login Manager's greeter is compiled in, and the 6.8.2 lock screen is the `lockscreen/` part of the shell package named by `ShellPackage`. Linux Hello can place its component in them only by owning a theme (SDDM) and a shell package (lock screen), or by changing upstream. A shell package fork also replaces what `plasmashell` loads when the same key is used, so the cheaper routes need a decision.
- **One component can be reused, but not one page.** A QML module installed in the system QML directory can be imported by an SDDM theme, a lock-screen shell package and the in-session Prompt UI, as `org.kde.breeze.components` already is by the first two. The surrounding page is separate in each host and tracks Breeze or `org.kde.plasma.desktop` as they change. UX5 ("identical look") holds for the component, not for the page.
- **The lock screen already shows face as a method, without a third-party component.** From 6.8 the stock lock screen lists Face (`kde-face`) and Fingerprint (`kde-fingerprint`) with a selector, and shows the service's PAM info and error text. Pointing `pam_linuxhello` at those service names covers UX2 and UX4 text on 6.8 with no QML of ours, but it gives no live camera state and runs one method per service, not the parallel face, fingerprint and PIN that UX3 needs. On 6.6.x this does not exist.
- **Subscribing is feasible once the Agent is on the system bus.** `SignalWatcher` (or an own plugin) can subscribe from QML, in all three hosts, if the Agent serves the signals on the **system bus**: the only bus every surface reaches (spike 0007). That makes four requirements:
  1. the bus ADR that spike 0007 asked for;
  2. a signal schema with a **prompt identifier** that the PAM module and the component can both derive; the SDDM and Plasma Login greeters see only free text, so the identifier cannot ride in the PAM conversation;
  3. a policy that keeps method and state from every local user: a broadcast signal reaches any local user (spike 0007), and the greeter user `sddm` is not the user who is signing in, so the Agent must address signals to a peer or the component must call a method and receive state in the reply;
  4. the module installed where `sddm`, `plasmalogin` and the user can read it, with its plugin loadable by each.
- **Not covered.** Plasma's polkit agent and other in-session authentication dialogs; screen readers and the on-screen keyboard in the greeters; HiDPI and multi-screen behaviour of a forked theme; a camera preview inside a greeter; any run.

**Design consequences.** The architecture's `Greeter and Lock Screen Integration` component should be split into: a shared QML module (`Auth Prompt QML Component`), an SDDM theme package, and a lock-screen shell package or an upstream change. Record in an ADR the choice between three routes for the lock screen: stock Face and Fingerprint service names (text only, 6.8 and later), a fork of `org.kde.plasma.desktop` limited to `lockscreen/`, or an upstream proposal for a method-state slot in `LockScreenUi.qml`. For SDDM, the choice is a Breeze fork or an upstream patch; for the Plasma Login Manager, an upstream patch only. [08 Crosscutting concepts](../arc42/08-crosscutting-concepts.md) lists this question as unverified; this note answers it for the source read above and leaves the runs to a disposable VM.
