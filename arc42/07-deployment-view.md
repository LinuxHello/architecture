---
type: architecture
subject: "Arc42 section 7: deployment view of Linux Hello (where the Agent is installed, how it starts and is confined, and what was tested)"
artifact: arc42-07-deployment-view
status: active
owner: "@atterdag"
concepts: [deployment, systemd, apparmor, arc42]
tags: [architecture, arc42]
sources: ["README.md", "12-glossary.md", "../workspace.dsl", "../adr/0014-agent-bus.md", "../adr/0018-user-policy-layer.md", "../adr/0021-pin-transport.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/agent-restart.md", "https://docs.arc42.org/section-7/"]
date: 2026-11-17
---

# 7. Deployment view

Part of the [Arc42 architecture documentation](README.md).

This section answers the question: where on a computer does Linux Hello run, and what keeps it safe there? [Section 5](05-building-block-view.md) lists the parts of Linux Hello; this section shows where the files of each part are installed, which user each runs as, and what limits it. Today only one part is installed and running, the [Agent](12-glossary.md#agent), so the section is about the Agent. The PAM module, the providers, the virtual security key and the Plasma parts have no installation files yet. Terms that may be new to you are in the [glossary](12-glossary.md).

## 7.1 Where the Agent is installed

The Agent is one background service for the whole computer. [systemd](12-glossary.md#systemd-systemd-service), the program that starts and supervises Linux services, starts it before the login screen appears. It runs as its own user `linuxhello`, not as root, and is reached over the [D-Bus](12-glossary.md#d-bus) system bus, the message channel that programs of every user share ([ADR-0014](../adr/0014-agent-bus.md)).

The diagram shows the Agent on an Ubuntu computer, with the system pieces around it: systemd, which starts it; AppArmor, which confines it; the system bus; the TPM; and the two directories it uses. It is generated from [workspace.dsl](../workspace.dsl) ([how](../diagrams/README.md)).

![C4 deployment view of the Linux Hello Agent on an Ubuntu workstation: systemd starts and sandboxes it, AppArmor confines it, it owns its name on the system bus, it will open the TPM, it reads and writes its state directory and reads the admin policy directory](../diagrams/AgentDeployment.svg)

Notice that the Agent touches only four things: the system bus, the TPM, its own state directory and the administrator's policy files. Everything else on the computer is closed to it.

The table lists every file that installing the Agent puts on the computer. The files come from the folders `security/` and `crates/linuxhello-agent` of the [linux-hello](https://github.com/LinuxHello/linux-hello) repository. No package builds them yet; the paths are the ones each file names in its header.

| File | What it is for | Source in `linux-hello` | Installed at |
| :-- | :-- | :-- | :-- |
| The Agent program | The service itself | `crates/linuxhello-agent` | `/usr/libexec/linuxhello/linuxhello-agent` |
| systemd unit | Tells systemd how to start, restrict and restart the Agent | `security/systemd/linuxhello-agent.service` | `/usr/lib/systemd/system/linuxhello-agent.service` |
| User and group | Creates the user `linuxhello` and puts it in the group `tss`, which may use the TPM | `security/systemd/linuxhello.sysusers` | `/usr/lib/sysusers.d/linuxhello.conf` |
| Bus policy | Tells the bus daemon who may own the Agent's name and who may call it | `security/dbus/io.github.LinuxHello.Agent1.conf` | `/usr/share/dbus-1/system.d/io.github.LinuxHello.Agent1.conf` |
| Bus activation file | Lets a call to a stopped Agent start it, by naming its systemd unit | `security/dbus/io.github.LinuxHello.Agent1.service` | `/usr/share/dbus-1/system-services/io.github.LinuxHello.Agent1.service` |
| AppArmor profile `linuxhello-agent` | Lists the files, devices and sockets the Agent may use; the kernel refuses the rest | `security/apparmor/linuxhello-agent` | `/etc/apparmor.d/linuxhello-agent` |
| State directory | Holds the users' root-key blobs, their policy layers and prompt data | created by systemd from the unit | `/var/lib/linuxhello`, readable only by `linuxhello` (mode 0700) |
| Admin policy | The administrator's rules | written by the administrator | `/etc/linuxhello/policy.d/`, read-only for the Agent |

## 7.2 How it starts, and what stops it

**It refuses to run unconfined.** [AppArmor](12-glossary.md#apparmor) is the kernel feature that limits a program to what its profile lists. Before the Agent starts, the unit checks that the profile `linuxhello-agent` is loaded in enforce mode, in which AppArmor blocks what the profile does not allow. If the profile is missing, or only logs violations instead of blocking them, the Agent does not start. This is Linux Hello's rule to [fail closed](12-glossary.md#fail-closed): it is better for the Agent to be absent, in which case the account password still works, than to run without its limits.

**It runs in a tight sandbox.** The unit gives the Agent no special privilege of root (no *capability*), no network except the local socket of the system bus, no access to home directories, a read-only view of the system, and one device: `/dev/tpmrm0`, the TPM. It never writes a core dump, because a dump of a process that holds a PIN would write the PIN to disk. systemd rates this sandbox at 0.5 on its exposure scale from 0 (fully closed) to 10, which it calls "SAFE". [Section 8](08-crosscutting-concepts.md#security-hardening) lists the threats this answers.

**Two independent layers decide who may talk to it.** The bus policy says that only the user `linuxhello` may own the Agent's name and send its signals, that any user may call its methods, and that nobody may read its properties. AppArmor separately limits what the Agent itself may do. A mistake in one layer is caught by the other.

**It starts on demand and comes back after a failure.** The Agent starts at boot, before the login screen. If it is stopped anyway, the first call to it starts it again, through the bus activation file. If it crashes, systemd restarts it after one second. If it hangs, a [watchdog](12-glossary.md#watchdog) notices: the Agent tells systemd that it is alive only after it has answered a call to itself over the bus, and if 30 seconds pass without that message, systemd restarts it. A restart loses every open sign-in attempt and every subscription, so every client follows one rule for what to do when that happens ([what a client does when the Agent restarts](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/agent-restart.md)).

### The PIN socket and the TPM provider

[ADR-0021](../adr/0021-pin-transport.md) gives the Agent a second way in: a local socket that carries the PIN and nothing else, so that the PIN never passes through the bus daemon. The Agent creates it as `/run/linuxhello/pin.sock`, in a directory that only the user `linuxhello` can change, and the AppArmor profile has a rule for it. A program announces the PIN over the bus with `ExpectPin` and then sends it on the socket; the Agent asks the kernel who is at the other end and accepts one PIN from exactly that program. The bus and this socket are the Agent's only two ways in.

The Agent has no TPM library of its own. A second, small program, the **TPM provider**, talks to the chip and nothing else. It runs as its own user (`linuxhello-tpm`) under its own AppArmor profile, which allows the TPM device and one socket, `/run/linuxhello-tpm/tpm.sock`, and denies the bus, the network and the Agent's files. Only the Agent's user may connect to that socket. The Agent sends it a stretched PIN, never the PIN, and the provider speaks to the TPM in an encrypted session.

Both programs have their own unit, bus policy where needed, system-user entry and profile under `security/` in the code repository, and both were installed in a virtual machine the way a package would and tested together: a user set a PIN with `linuxhello-ctl pin set`, changed it, and the TPM accepted only the new one. That test used a software TPM, on Ubuntu 26.04 only (the provider links system libraries, so it is built per release).

## 7.3 What has been tested

A script installed the files above in a virtual machine and exercised the Agent on a real system bus with real users, on **Ubuntu 24.04** (kernel 6.8) and **Ubuntu 26.04** (kernel 7.0, AppArmor 5, systemd 259). When this section was first written the script made 22 checks, and all passed on both versions. They showed that:

- the unit starts only with the profile enforcing, and refuses otherwise;
- the Agent owns its name and runs confined;
- any user reaches its methods, and nobody reads its properties;
- another user is refused on a sign-in attempt it did not open, and cannot take the Agent's name;
- a subscriber hears the Agent's signal, while a bystander and two forgers achieve nothing;
- the profile blocks what it does not allow, and blocks nothing the Agent needs.

The script has grown since. Its later checks, that a call to a stopped Agent starts it and that a killed Agent is back within two seconds, have run on Ubuntu 24.04 only, because the 26.04 image does not boot in the test machine at the moment. The script lives in the maintainer's private workstation repository and is run by hand. Since [linux-hello#239](https://github.com/LinuxHello/linux-hello/pull/239) the same confinement checks also run in continuous integration on a real system bus; [linux-hello#149](https://github.com/LinuxHello/linux-hello/issues/149) tracks the remaining ones.

These runs found two defects that no unit test could have found. First, systemd runs the Agent in its own view of the file system, in which AppArmor sees the path of the bus socket without its leading slash and blocked the connection; the profile needs the flag `attach_disconnected` for that. Second, the bus activation file named its section `[D-Bus Service]`, which the bus daemon silently ignores; it must be `[D-BUS Service]` ([linux-hello#194](https://github.com/LinuxHello/linux-hello/issues/194)).

## 7.4 Not yet covered

- **The other parts.** The PAM module, the TPM provider, the KeePassXC bridge, the virtual security key with its `uhid` helper, and the Plasma parts each need installation files, a bus policy and an AppArmor profile of their own. None is written.
- **The TPM.** The unit already allows `/dev/tpmrm0`, but the Agent does not open it yet. Only a software TPM was tried.
- **The user's policy layer** is built: the Agent keeps each user's layer in its state directory and users change it over D-Bus (`GetUserPolicy`, `SetUserPolicy`), so the Agent needs no access to home directories ([ADR-0018](../adr/0018-user-policy-layer.md); linux-hello pull requests 114 and 115).
- **Other distributions.** Only Ubuntu was tested. Which distributions Linux Hello supports is not decided yet, and with it whether a confinement system other than AppArmor is needed: Fedora, for example, uses SELinux.
- **Packages and updates.** Nothing builds a `.deb` or installs these files automatically yet. How releases are built and proven to come from the reviewed code is decided in [ADR-0006](../adr/0006-attested-quality-gates-and-releases.md).
