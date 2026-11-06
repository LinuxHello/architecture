---
type: spike
subject: PAM module publishes method state over the Agent's D-Bus API
artifact: spike
status: answered
owner: "@atterdag"
concepts: [pam, dbus, sddm, kscreenlocker, sudo, login, apparmor, method-state]
tags: [spike, m0, upstream]
sources:
  - https://github.com/sddm/sddm/tree/4fe234b
  - https://invent.kde.org/plasma/kscreenlocker/-/tree/v6.6.6
  - https://github.com/sudo-project/sudo/tree/v1.9.17p2
  - https://gitlab.freedesktop.org/dbus/dbus/-/tree/dbus-1.16.2
  - https://github.com/systemd/systemd/tree/v259
  - https://github.com/torvalds/linux/tree/v7.0
date: 2026-11-06
issue: https://github.com/LinuxHello/linux-hello/issues/7
---

# Spike: PAM module publishes method state over the Agent's D-Bus API

## Question

Can `pam_linuxhello` run face, fingerprint and PIN in parallel and publish their state on the Agent's D-Bus API from inside a PAM conversation, in each context it runs in: the SDDM greeter, the Plasma lock screen, `sudo`, and login on a text console?

## Time box

Two working days proposed. This pass is **desk research only**, by the maintainer's decision: it answers what upstream source settles, at the versions Ubuntu 26.04 ships, and lists what still needs a run. No PAM module was built or installed.

## Method

For each context, read the upstream source that loads the PAM stack, at the packaged version, and establish: which process calls `pam_authenticate`, with which user ids; whether a session bus exists at that point; whether the system bus admits the process; and what the bus policies allow without configuration.

| Component | Version read | Files |
| :-- | :-- | :-- |
| SDDM | 0.21.0+git `4fe234b` | `src/helper/HelperApp.cpp`, `src/helper/backend/PamBackend.cpp` |
| kscreenlocker | Plasma 6.6.6 | `greeter/pamauthenticator.cpp`, `greeter/pamauthenticators.cpp`, `greeter/greeterapp.cpp`, `greeter/main.cpp`, `greeter/CMakeLists.txt`, `CMakeLists.txt` |
| sudo | 1.9.17p2 | `plugins/sudoers/sudoers.c`, `plugins/sudoers/check.c`, `plugins/sudoers/set_perms.c`, `plugins/sudoers/auth/pam.c` |
| login | util-linux 2.41.3 (Ubuntu's `login` package) | package metadata only |
| dbus | 1.16.2 | `bus/policy.c`, `bus/session.conf.in`, `bus/system.conf.in` |
| pam_systemd | systemd 259 | `src/login/pam_systemd.c` |
| Linux | 7.0 | `net/core/sock.c` (`cred_to_ucred`) |

Every finding below: **tested** as source reading (files fetched at the named tags with `gh api` and `curl`). Nothing was run against a live PAM stack: **untested** at runtime.

## Evidence

1. **SDDM greeter.** `sddm-helper` calls `pam_authenticate` as root: `HelperApp.cpp` asserts `getuid() == 0` right before `m_backend->authenticate()` (line 153). The service is `sddm` for a user login (`PamBackend.cpp`, lines 220–226). The conversation function forwards prompts to the daemon, which relays them to the greeter (`PamBackend::converse`, line 298). Authentication happens before the user has a session.
2. **Lock screen.** `kscreenlocker_greet` runs as the logged-in user and calls PAM in-process, on a worker thread (`pamauthenticator.cpp`: `pam_start` line 222, `pam_authenticate` line 175, `moveToThread` line 257). It runs **one interactive service, `kde`, and non-interactive services `kde-fingerprint` and `kde-smartcard` in parallel**, each its own PAM handle (`greeterapp.cpp`, lines 137–142; names in `greeter/CMakeLists.txt`, lines 75–80). The first success unlocks, and a failure of the interactive one cancels the others (`pamauthenticators.cpp`, lines 46–75). There is no seccomp filter in the 6.6.6 greeter; it only sets `PR_SET_DUMPABLE` (`main.cpp`, line 71). The user's session bus exists.
3. **sudo.** Authentication runs with the setuid process's initial credentials: `sudoers_check_cmnd` sets `PERM_INITIAL` (`sudoers.c`, line 668) before `sudoers_check_common` (line 701) reaches `check_user` and `pam_authenticate` (`auth/pam.c`, line 322). `PERM_INITIAL` is the state at exec, read with `getresuid` (`set_perms.c`, line 140): real uid the invoking user, effective uid 0.
4. **Text console.** `login` (util-linux 2.41.3) runs as root under `getty`; authentication precedes the session.
5. **Session bus address.** `pam_systemd` exports `DBUS_SESSION_BUS_ADDRESS` and `XDG_RUNTIME_DIR` only from `pam_sm_open_session` (`pam_systemd.c`, lines 1491, 1527, 1725); it has no `pam_sm_authenticate`. During authentication at the greeter or a console no session bus address is set.
6. **Who a bus admits.** The kernel reports a Unix peer's **effective** uid (`cred_to_ucred`: `ucred->uid = … cred->euid`). dbus admits by default only the user that owns the bus (`bus_policy_allow_unix_user`, `policy.c`, line 462). The session bus configuration adds no other users (`session.conf.in`), so **a process with effective uid 0, the SDDM helper, `sudo` and `login`, cannot use the user's session bus** even when one exists. The system bus admits every user (`system.conf.in`, line 46: `<allow user="*"/>`).
7. **What the system bus allows without configuration.** Signals may be sent (`<allow send_type="signal"/>`, line 55); owning a name and method calls are denied (`<deny own="*"/>`, `<deny send_type="method_call"/>`, lines 50–51) unless a policy file under `/usr/share/dbus-1/system.d/` allows them. A broadcast signal on the system bus can be received by any local user.
8. **AppArmor.** Ubuntu 26.04 ships a profile for `plasmashell`, none for `sddm`, `sddm-helper`, `kscreenlocker_greet`, `sudo` or `login`: they run unconfined.

| Context | Calls PAM as | Session bus | System bus |
| :-- | :-- | :-- | :-- |
| SDDM greeter | root (`sddm-helper`) | none yet; would refuse root | yes |
| Lock screen | the user (`kscreenlocker_greet`) | yes | yes |
| `sudo` | real uid user, effective uid 0 | refuses effective uid 0 | yes |
| Text console | root (`login`) | none yet; would refuse root | yes |

**Not done, so untested:** a prototype module opening a system bus connection in each context and sending to the Agent; how long a connection takes inside the conversation; whether an async runtime in the module coexists with kscreenlocker's worker thread; which environment `sudo`'s environment replacement leaves the module; the lock screen with `kde-fingerprint` configured.

## Answer

**Partly.**

- **The system bus is reachable in all four contexts; the session bus only at the lock screen.** So the PAM module can reach the Agent everywhere only if the Agent serves the PAM module on the **system bus**: as a system service, or through a system-bus endpoint. The architecture does not yet say which bus the Agent uses ([07 Deployment view](../arc42/07-deployment-view.md) records it as a gap). This answer decides it, and needs an ADR, because D-Bus names and the bus they live on are a one-way door.
- **Publish by calling the Agent, not by broadcasting.** A signal needs no configuration but any local user can receive it, so it would tell every user who is authenticating with which method. A method call to the Agent needs a system bus policy for `io.github.LinuxHello.Agent1`, and the Agent checks the caller's credentials, as `workspace.dsl` already requires of `dbusApi`.
- **Parallel methods differ by context.** At the lock screen Plasma already runs fingerprint and smartcard as separate PAM services in parallel with the password. There, `pam_linuxhello` running its own parallel face, fingerprint and PIN in the `kde` service would compete with `kde-fingerprint`. At SDDM, `sudo` and the console there is one PAM conversation, and the module must run the methods in parallel itself. The `Method Orchestrator` component in `workspace.dsl` assumes the latter everywhere.
- **The PAM boundary holds:** nothing found forces the PAM module and the Agent into one process.

Follow-ups: an ADR on the Agent's bus (system service or system-bus endpoint) and its policy; a decision on the lock screen's parallel methods; then the runs listed above, in a disposable VM, before the PAM module is implemented.
