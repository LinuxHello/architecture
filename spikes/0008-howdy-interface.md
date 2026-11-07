---
type: spike
subject: Howdy interface for live preview, enrolment and test
artifact: spike
status: answered
owner: "@atterdag"
concepts: [howdy, face, ir-camera, pam, enrolment]
tags: [spike, m0, upstream]
sources:
  - https://github.com/boltgolt/howdy/tree/v2.6.1
  - https://github.com/boltgolt/howdy/tree/d3ab99382f88f043d15f15c1450ab69433892a1c
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/8
---

# Spike: Howdy interface for live preview, enrolment and test

## Question

Does Howdy expose a library, D-Bus or CLI interface that supports live preview, enrolment and a test match without going through PAM?

## Time box

Proposed: 2 working days. This pass is a **source read only**; no IR camera was available, so nothing was run. The camera-dependent checks are listed under Method as untested.

## Method

Read Howdy's source at two refs, fetched with `gh api` and `curl` from `raw.githubusercontent.com/boltgolt/howdy/<ref>/`:

| Ref | What it is | Commit |
| :-- | :-- | :-- |
| `v2.6.1` | The latest GitHub release (2020-09-02); `src/cli.py` line 111 prints `Howdy 2.6.1` | `3c9537a35f23773ceca86e79be1ebed3ebe774cc` |
| `master` | Unreleased 3.0.0 beta; 273 commits ahead of `v2.6.1`, head dated 2025-06-22; `howdy/src/cli.py` line 118 prints `Howdy 3.0.0 BETA` | `d3ab99382f88f043d15f15c1450ab69433892a1c` |

`v2.6.1` is the primary reading because it is the release. `master` is read to show where the interface is heading; it has no release tag and its layout differs (C++ PAM module, `howdy-gtk`, meson build).

```sh
R=https://raw.githubusercontent.com/boltgolt/howdy
curl -sS $R/v2.6.1/LICENSE
gh api "repos/boltgolt/howdy/git/trees/v2.6.1?recursive=1" --jq '.tree[].path'
for f in src/cli.py src/cli/add.py src/cli/test.py src/cli/list.py src/cli/snap.py \
         src/compare.py src/pam.py src/recorders/video_capture.py; do curl -sSf $R/v2.6.1/$f; done
# the same for master at d3ab993, under howdy/src/ and howdy-gtk/src/
grep -rn -i -E "dbus|socket" <both trees>
```

Tested (as source reading): all commands above. **Untested** (needs an IR camera and a Howdy install):

- `howdy add`, `howdy test`, `python3 compare.py <user>` and `howdy-gtk` against real hardware;
- whether `compare.py` can run as a non-root user, and the file mode and owner of the models directory;
- the cost of a cold start (dlib model load, camera open) per call;
- the polkit policies (`fedora/com.github.boltgolt.howdy.policy` at `v2.6.1`, `howdy-gtk/src/polkit/` on `master`): listed in the tree, not read.

## Blocks

The face enrolment wizard needs the IR detection results and a preview. The PAM module needs a match call it can run in parallel with fprintd. Blocks the face enrolment wizard and the parallel face method in `pam-linuxhello`.

## Evidence

Line numbers refer to the file at the named ref. Paths without a prefix are in `src/` at `v2.6.1`; `m:` means `master` at `d3ab993` (under `howdy/src/` unless stated).

**Licence**

1. `LICENSE` at `v2.6.1` and at `d3ab993` begins "MIT License", "Copyright (c) 2018 boltgolt". GitHub reports SPDX `MIT` for the repository. This covers Howdy's own code only; I did not check the licences of dlib, OpenCV or the dlib model files that `dlib-data/install.sh` downloads (see [spike 0013](0013-upstream-licences.md)).

**Entry points at `v2.6.1`**

2. **No D-Bus service and no socket.** `grep -i -E "dbus|socket"` over `src/` at `v2.6.1` and over `howdy/` and `howdy-gtk/` at `d3ab993` finds nothing.
3. **No installable Python library.** The tree has no `setup.py` or `pyproject.toml`. The modules are scripts that run at import: `cli/add.py` loads the dlib models (lines 41–48), reads the camera (lines 101–161) and writes the model file (lines 195–196) at module level, and `cli/test.py` runs its window loop at module level (lines 82–203). Nothing can be imported and called as a function. The one reusable class is `recorders/video_capture.py::VideoCapture` (constructor line 18, `read_frame` line 64, `release` line 57), which takes a `configparser` object (line 23) and calls `sys.exit(1)` on a bad device path or failed read (lines 36, 79).
4. **CLI `src/cli.py`**, command choices `add, clear, config, disable, list, remove, snapshot, test, version` (line 41). It refuses to run unless `SUDO_USER` is set (lines 83–86) and refuses user `root` (lines 89–91). `-U/--user` selects the user (lines 50–53), `-y` skips questions (lines 56–59).
5. **PAM module `src/pam.py`**, a pam-python module (line 10: "pam-python is running python 2"). `pam_sm_authenticate` (line 91) calls `doAuth`, which runs `/usr/bin/python3 compare.py <user>` as a subprocess (line 44) and maps its exit status to a PAM result (lines 47–88).
6. **Matcher `src/compare.py`**, a script that takes the user name as `argv[1]` (lines 66, 73). It does not import PAM. Exit status is the whole interface: 0 match (line 286), 10 no model (lines 100, 104), 11 timeout (line 182), 12 abort (line 67), 13 too dark (line 180). Output is free text and only when `end_report` is set (lines 252–279).

**Can each operation be driven without PAM?**

7. **Test match: partly.** `python3 compare.py <user>` runs the same code the PAM module runs, without PAM (item 6). Missing from that interface: it returns only pass or fail, with no score, no face box and no frame. The best distance appears only in the text report (line 277) and the winning model in line 279. The threshold is `certainty` in `config.ini` (line 114 of `compare.py`).
8. **Enrolment: yes, as a CLI call, with limits.** `sudo howdy -U <user> add -y` (item 4; `cli/add.py` lines 82–90) captures up to 60 frames (line 126), stops at the first frame with exactly one face (lines 160–161, 177–179), computes one 128-dimension dlib descriptor (line 187) and appends it to `models/<user>.dat` as JSON `{time, label, id, data}` (lines 93–98, 195–196). Results are text on stdout and exit status 1 on failure (lines 168–179); there is no machine-readable output and no progress callback. `-y` takes the default label, so a label cannot be passed at `v2.6.1`. Each enrolment stores **one** encoding per model. On `master`, `add` accepts the label as an argument (`m: cli/add.py` lines 83–84) and a `--plain` flag (`m: cli.py` line 60; `m: cli/add.py` line 73) that suppresses the header; failures are still text.
9. **Live preview: no.** `howdy test` opens an OpenCV window (`cli/test.py` lines 65, 176) and quits on a key press or Ctrl+C (lines 179–180, 198–203); it exits 12 if `recording_plugin` is not `opencv` (lines 19–22). Frames are not exposed to another process. The overlay shows resolution, FPS, frame count, recognition time, an 8-bin brightness histogram, a "DARK FRAME" or "SCAN FRAME" flag and a circle per detected face (lines 99–173). `master` keeps this for `howdy test` (`m: cli/test.py` lines 83, 223).
10. **`master` adds a GTK UI, not an API.** `m: compare.py` starts `howdy-gtk --start-auth-ui` as a child and writes `M=<text>` and `S=<text>` lines to its stdin (lines 81–95, 157, 163, 211, 228). That is a one-way status feed to Howdy's own window and it is not a documented interface. `howdy-gtk`'s video tab opens the camera itself with `cv2.VideoCapture` and shows PNG-encoded frames (`m: howdy-gtk/src/tab_video.py` lines 34, 72); its models tab shells out to `howdy add` and `howdy remove` (`m: howdy-gtk/src/tab_models.py` lines 85, 114). So even Howdy's own GUI uses the CLI for enrolment and has no shared library.
11. **List, remove, clear, snapshot.** `list` prints a table for people (`cli/list.py` lines 31–44); `remove` and `clear` edit the JSON file; `snapshot` prints the path of a generated image (`cli/snap.py` lines 50–51). The model file is plain JSON at `<install dir>/models/<user>.dat` (`cli/add.py` line 52). On `master` the directory is set at build time (`paths.py.in`, `user_models_dir`; `meson.build` line 4, default `<confdir>/models`).
12. **Camera access.** `VideoCapture` opens a V4L2 device by `device_path` through OpenCV, `ffmpeg` or `pyv4l2` (`recorders/video_capture.py` lines 97–117). `compare.py`, `add` and `test` each open the camera exclusively for their run. Whether this coexists with PipeWire holding the device is the subject of [spike 0012](0012-camera-rgb-ir-concurrent.md) and was not checked here.
13. **`master` PAM module.** `m: pam/main.cc` spawns `python3 compare.py <user>` with `posix_spawnp` (lines 265–272) and reads the exit status (lines 286, 356). The status codes become a C++ enum `CompareError`: 10 no model, 11 timeout, 12 abort, 13 too dark, 14 invalid device, 15 rubber stamp (`m: pam/main.hh` lines 13–20). The subprocess contract is the same as at `v2.6.1`.

**What `Face Client` and the enrolment wizard would call**

14. **Face method (`pam_linuxhello` / `Face Client`).** The only Howdy call that matches without PAM is `python3 <install dir>/compare.py <user>` and reading its exit status, as both PAM modules do (items 5, 13). It needs the user's model file and the camera, takes the whole `timeout` (default 4 s at `v2.6.1`, `config.ini` line 37) when no face matches, and cannot be cancelled except by killing the process. Whether the process can run as the user rather than root: **not established**.
15. **Enrolment wizard (Plasma, Qt).** Howdy gives it nothing to render. The wizard needs frames and face boxes while the user positions their face, and a per-frame darkness value for the IR emitter check; the only place Howdy computes these is inside `cli/test.py` (items 9, 10), which draws them into its own window. For the final capture the wizard can run `howdy -U <user> add -y` and read the exit status, but the call needs `SUDO_USER` set (item 4), so it needs privilege escalation; whether Howdy's polkit policy supports a non-terminal caller: **not read**.

## Answer

**Partly.**

- **Test match: Yes, as a subprocess.** `compare.py <user>` runs without PAM and returns 0 or a failure code (item 6). It gives no score and no frames. This is enough for the parallel face method in `pam-linuxhello` to treat Howdy as a black box with a pass or fail result; the `Face Client` component should be a subprocess runner, not a library client.
- **Enrolment: Partly.** `howdy add` works without PAM and writes a JSON model (format defined only by the code), but it is a root-only CLI with text output, one encoding per model and no progress reporting (item 8).
- **Live preview and IR detection results: No.** No Howdy interface exposes frames, face boxes or brightness to another process (items 3, 9, 10). The enrolment wizard cannot get a preview from Howdy at either ref.
- **Design consequence.** The enrolment wizard needs a capture-and-detect component that Linux Hello owns, or an upstream change to Howdy that exposes one. Options for the next step, not decided here: (a) implement the preview and enrolment in the Agent with dlib and OpenCV and write Howdy's JSON model format so `compare.py` keeps working; (b) contribute a library or machine-readable interface upstream; (c) use `howdy add` for the capture and accept no preview. Each needs an ADR; none is chosen. [Constraint C1](../arc42/02-constraints.md) (reuse, do not reimplement) bears on (a).
- **Not covered:** anything that needs the camera (items listed untested under Method); whether Howdy's `master` beta will be released and keep this subprocess contract; the licences of dlib and its model files; running `compare.py` as a non-root user and the model file permissions; the Howdy polkit policies; concurrency with fprintd and with the PAM stack contexts in [spike 0007](0007-pam-dbus-method-state.md); and Howdy's security properties (no liveness check was looked for in this pass).
