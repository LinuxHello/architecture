---
type: spike
subject: Resident keys, user presence and user verification in the virtual CTAP authenticator
artifact: spike
status: answered
owner: "@atterdag"
concepts: [ctap, resident-key, discoverable-credential, user-presence, user-verification, prompt-ui, credential-index, firefox, chromium, apparmor]
tags: [spike, m0, security]
sources: ["0094-virtual-ctap-end-to-end.md", "0119-rp-bound-credential-keys.md", "0121-uhid-helper-privilege.md", "../adr/0017-browser-path.md", "https://fidoalliance.org/specs/fido-v2.0-ps-20190130/fido-client-to-authenticator-protocol-v2.0-ps-20190130.html"]
date: 2026-11-15
issue: https://github.com/LinuxHello/linux-hello/issues/120
---

# Spike: Resident keys, user presence and user verification in the virtual CTAP authenticator

## Question

Can the virtual CTAP authenticator offer discoverable credentials, a user-presence prompt on every request and user verification mapped to the Agent's unlock, and show the user a provider choice where per-relying-party routing needs one? And, because [#139](https://github.com/LinuxHello/linux-hello/issues/139) depends on it: can a process of the same user forge presence or verification (synthetic input, `ptrace`, preload, an impostor prompt), and how is one signature per request guaranteed when Firefox repeats `getAssertion`?

## Time box

Proposed: 3 working days. Done in one long session; the prototype is Python on `tpm2-tools`, not Rust.

## Method

**Environment (tested).** The test VM from `make vm-up` in `linux-hello-workstation`: Ubuntu 24.04.5, kernel 6.8.0-147-generic, KVM (QEMU 10.2.1), a TPM 2.0 from swtpm 0.10.1, AppArmor parser 4.0.1, Python 3.12.3. In the guest: `tpm2-tools` 5.6, `fido2-tools` (libfido2) 1.14.0, python-fido2 2.2.1 (a raw CTAP client with exact control of every request), `xdotool` (synthetic input through XTEST), `xinput`, `strace`, `gdb`, `Xvfb`. No hardware was involved: no hardware TPM, no fingerprint sensor, no real desktop session. The browser runs are headed under `Xvfb` as an unprivileged user (`/dev/hidraw*` opened to that user, as a distribution udev rule typically does for FIDO keys).

**Prototype (tested).** `scripts/spike-0120/` in `linux-hello-workstation` (`lhctap2.py` extends the spike 0094 `lhctap.py`; the other files are the stub prompt, the simulated person, the page and the test drivers). Run as root in the VM. What it adds to 0094:

- `getInfo` options `rk` and `up` true; `uv` true only when the Agent can verify the user at that moment (a verifying gesture is configured, or a verification event is inside the window).
- **Credential Index** (`index.json` in the Agent's state): a resident credential is a random 16-byte handle (the credential ID, 19 bytes) mapped to relying party, user entity, provider and the TPM-wrapped key blobs. A `get` without an allow list is answered from it. Non-resident credentials stay self-contained blobs as in 0094.
- **Stub Prompt UI** (`lh-prompt-stub`, Tk): the Agent starts it as its own child, accepts its connection only if the peer's pid is that child and its AppArmor label (`SO_PEERSEC`) is `lh-prompt-stub (enforce)`, and sends it the relying-party id of the request and, for a choice, labels it took from the Index. Nothing else the client sent is shown. It is not dumpable (`PR_SET_DUMPABLE=0`) and has its own AppArmor profile (`lh-prompt-stub.apparmor`).
- **Three presence gestures**: `click` (an Allow button), `pin` (the PIN typed into the prompt, checked by the TPM: a wrong PIN counts as an attempt, as in spike 0094) and `sensor` (a `match` written to a socket only root can write, standing in for fprintd's verified event; the prompt is display-only, nothing in it can be clicked).
- **UV rule** (the decision on #139): UV=1 only if the user was verified for this request (`pin`, `sensor`) or, when the request asks for UV, within `min(policy, 60 s)` of a verification event (`unlock`, a session unlock standing in). A click is never a verification. The 60 s cap is a constant in the code; the policy value is clamped to it (and `nan`, negative, `inf` are handled).
- **One signature per request**: an identical `getAssertion` repeated on the same channel within 30 s gets the stored response; a request with `up=false` (a silent probe) is answered without using the key; `getNextAssertion` is implemented.
- CTAPHID keepalives (status 2, "user presence needed") while waiting, `CHANNEL_BUSY` for another channel, cancel; events as JSON lines (`events.jsonl`) so a test can count prompts and signatures.

**Script (tested).** `make vm-test-uvup` (`scripts/vm-test-uvup.sh`), run on 2026-11-15: sections A (authenticator), B (Playwright browsers) and C (what #139 needs) in one run, 70 checks, `ALL PASSED`, 11 minutes; the opt-in section D (Chrome stable and the Snaps), 4 checks, `ALL PASSED` in a separate run. A `PASS` for a check named `*_is_still_possible` means the thing is possible, that is, the design does not stop it. The first runs of each section failed on faults in the script (a shadowed `as` command, stale prompt windows, a coordinate); those were fixed and are not findings about the design.

**Clients (tested).** python-fido2 2.2.1 (raw CTAP2); libfido2 1.14.0 (`fido2-cred`, `fido2-assert`: development runs, not in the script); Chromium 156.0.8078.4 and Firefox 157.0 (Playwright builds); Chrome stable 157.0.8103.78 (the `.deb`), Chromium 157.0.8103.50 (Snap rev 3593) and Firefox 160.0-1 (Snap rev 9181), all with the `u2f-devices` interface connected as the Snap store connects it; a local page on `http://localhost:8000/`.

**Untested.** A hardware TPM, `tss-esapi`, fprintd and a fingerprint sensor, Howdy, a Wayland session, the real Prompt UI (QML), Flatpak browsers, Firefox as a `.deb`, a real relying party such as webauthn.io, other distributions and Ubuntu 26.04, `credentialManagement`, exclude lists, CTAP 2.1 (selection, `credProtect`, `hmac-secret`), hotplug and suspend, the browsers' own account choosers with two or more credentials, the KeePassXC provider (a tag on a second Index entry stands in for it), Yama and dumpable settings on other distributions.

## Evidence

### Authenticator (section A, raw client)

| What | Result |
| :-- | :-- |
| `getInfo` | `rk`, `up` true; `uv` false for a click-only Agent, true for `pin` or `sensor`, true for the window after a verification event, false again after `forget` |
| Resident create | OK; credential ID is a 19-byte handle, the Index holds relying party, user (`id`, `name`) and wrapped blobs; one prompt, one signature |
| `get`, no allow list | finds the discoverable credential; returns the user handle; UP=1, UV=0 after a click |
| `get`, handle in the allow list | OK; another relying party's `rpId` gives `NO_CREDENTIALS` |
| Presence on every request | three requests, three prompts, three signatures; nobody at the prompt: fails after the timeout, no signature; Deny: `OPERATION_DENIED`, no signature |
| UV, no verification | refused (`OPERATION_DENIED`), no signature, although the user clicked Allow: a click is not verification |
| UV with a sensor match / the right PIN | UV=1, "this request" |
| Wrong PIN typed | no signature; the TPM's lockout counter goes up |
| UV window | right after a verification event: UV=1 with presence still asked for each request; policy 3 s: closed after 4 s; policy 600, `inf`: effective window 60 s; `nan`, negative: no window; 600 s policy, 62 s after the verification: refused |
| Keepalive / busy | a second client while a prompt is open gets `CHANNEL_BUSY`, no second prompt |
| Two resident credentials, no prompt choice | `numberOfCredentials` = 2, **two signatures after one prompt** (the second at `getNextAssertion`): the browser's chooser decides, the key signs for credentials the user did not pick |
| Two credentials, the Prompt UI asks which (provider choice) | one prompt, **one signature**, no `numberOfCredentials`; either credential can be chosen |

### Browsers (section B and D)

The page runs `create` and `get`; the table is what the page reported. "Agent" is the gesture the Agent was set to.

| Request | Chromium 156 / Chrome 157 | Firefox 157 / 160 (Snap) |
| :-- | :-- | :-- |
| `create`, defaults, any Agent | OK; 1 prompt, 1 signature; `cross-platform` | OK; 1 prompt, 1 signature; `cross-platform` |
| `create` `residentKey: required`, `userVerification: required`, sensor or PIN Agent | OK, UV=1 | OK, UV=1 |
| `get` with the credential in the allow list, UV required | OK, UV=1; 1 prompt | OK, UV=1; 1 prompt (and one silent probe, below) |
| `get` with **no** allow list, UV required or discouraged | OK after the user presses *Continue* in Chromium's own "Use a saved passkey" dialog, which appears even for one credential and shows the user name; the Agent has already signed when it appears | OK at once, no dialog for one credential |
| click-only Agent (`uv` not advertised), `create` or `get` with UV `required` | **waits** until the page times out: it shows "Insert your security key and touch it" and no request reaches the Agent (the dialog is Chromium's own; this is the wait seen in spike 0094) | creates and gets, UV=0: Firefox does not enforce the requirement, the relying party must check the flag (as 0094) |
| Chrome stable `.deb`, Chromium Snap, Firefox Snap, sensor Agent, `create` resident + UV then `get` | OK, UV=1, 2 signatures each (Chrome 157.0.8103.78, Chromium Snap 157.0.8103.50) | OK, UV=1 (Firefox Snap 160.0-1) |

The Snaps reach `/dev/hidraw*` through the `u2f-devices` interface, which was connected without any action. Flatpak was not tried.

**What Firefox sends twice.** Two `getAssertion` on one channel. The first has `up=false` and a client-data hash of `e3b0c442...`, the SHA-256 of the empty string: a silent probe whether the device knows the credential. The second is the real request. They are different requests, so repeating the same one is not what Firefox does; a "repeat of the same request" cache would not catch it. Policies for the probe, tried against Firefox 157 (the last row is about Chromium's and Firefox's selection probes):

| Probe policy | Result |
| :-- | :-- |
| Sign it (spike 0094) | the key signs twice per `get`, once with UP=0 and no presence, over a hash an attacker can request too |
| Refuse it (`UNSUPPORTED_OPTION`) | Firefox falls back to a `makeCredential` for the relying party `make.me.blink` and the `get` fails with `NotAllowedError` |
| Answer without the key (a well-formed response with an invalid signature, no counter increment) | `get` OK, **one prompt, one signature per `get`** |
| Treat `makeCredential` for `.dummy` (Chromium's selection probe) and `make.me.blink` as probes: refuse, no prompt, no key | no extra prompt; the probes are not credential requests |

Chromium 156 and Chrome 157 sent one `getAssertion` per `get`.

### What #139 needs (section C): a process of the same user against the prompt

The "person" is a script that acts through XTEST (`xdotool`); to the Agent it is indistinguishable from a user's click or typing.

| Attack | Click-only presence | Sensor presence |
| :-- | :-- | :-- |
| Synthetic click on the prompt | **signature** (also when the prompt is confined under AppArmor and the Agent saw the confined label) | none: nothing in the prompt can be clicked |
| Synthetic typing of the PIN | n/a | none |
| A sensor match from the user | n/a | the signature, UV=1 |
| The user writes the sensor or control socket | n/a | refused: mode 0600, root |
| An impostor: a same-user process connects to the prompt socket and answers allow and the PIN | refused by pid; it never receives the request or the relying party; the same with a second copy of the real prompt binary, which has the right label | same |
| Attach with `strace` or `gdb` to the Agent's prompt | refused | refused |
| Preload (`LD_PRELOAD`) into a prompt the user starts | not applied under the profile (the transition scrubs it); applied when the profile is off | same |

Ptrace, one layer at a time, with an unconfined process of the same user as the attacker:

| Yama `ptrace_scope` | Prompt not dumpable | AppArmor profile | Attach |
| :-- | :-- | :-- | :-- |
| 1 (Ubuntu default) | yes | yes | refused |
| 0 | yes | yes | refused |
| 0 | yes | no | refused (the flag alone) |
| 1 | no | no | refused (Yama alone: not your child) |
| 0 | no | yes | **allowed**: the profile alone does not stop an unconfined tracer |
| 0 | no | no | allowed (control) |

A process of the same user that starts its own copy of the prompt and traces it from `exec` works even under the profile (tracing what you started is allowed); that copy is not the Agent's child and cannot answer for the Agent.

Further observations:

- **A same-user X client reads the PIN typed into the prompt.** `xinput test-xi2 --root` recorded the key codes of all six digits while they were typed into the confined prompt. Under X11 a PIN prompt gives no secrecy against a process in the session. A Wayland compositor was not tested.
- **Three wrong PINs through the prompt lock the TPM.** A process that can type can use up the attempts (a denial of service, not a forgery).
- **UV from the window is the same exposure as a click.** After a verification event, within the window, a click gives UV=1 (that is the rule), so a synthetic click obtains UV=1 there (`uv_within_the_window_is_obtained_by_a_synthetic_click_is_still_possible`). See *Open for ADR-0020*.

## Answer

| Item | Answer | In short |
| :-- | :-- | :-- |
| Resident keys | **Yes** | Create, `get` with and without an allow list, user handle returned, UV=1 on a resident credential, in Chromium 156, Chrome 157 and Firefox 157 and 160 (Snap) |
| User presence on every request | **Yes** for the mechanism; **Partly** for what it stops | One prompt and one signature per request. A click-only presence is forgeable by a process of the same user (also confined). Only a gesture the session cannot synthesise is presence: a sensor match delivered to the Agent, or the PIN checked by the TPM (the PIN is readable by an X client) |
| User verification | **Yes** | UV=1 for this request's verification or inside a window of at most 60 s, the cap enforced in code; `uv` in `getInfo` only when it can be satisfied. Chromium waits and Firefox ignores UV when it is not offered, so a click-only Agent is a degraded class |
| Provider choice | **Partly** | The Prompt UI can ask which credential (provider) and then sign once: tested with two tagged credentials and the raw client. The browsers show only "USB security key"; their own choosers with two credentials and the KeePassXC provider were not tested |
| One signature per request | **Yes** | Answer the silent probe (`up=false`) without the key; prompt and sign once for the real request; one gesture per request; with no prompt choice, `numberOfCredentials` > 1 signs for each credential |
| Same-user process against the prompt (#139) | **Partly** | Sensor presence: synthetic input, impostor, `ptrace` and preload produce no signature. Click presence: synthetic input does |

**What the Yes does not cover.** Software TPM only; a Tk stub, not the QML Prompt UI; no fprintd; X11, not Wayland; one distribution release. The prompt runs as a child of a root Agent here. In the real design the prompt is started in the user's session, not as the Agent's child, so the pid check does not carry over: what carries over is that in sensor mode the decision never passes through the prompt, so a rogue copy of it decides nothing, and in PIN mode the TPM checks the PIN. For click-only presence nothing carries over.

## What it changes in the architecture

Proposed in this change: [workspace.dsl](../workspace.dsl) (`Credential Index`, `Prompt UI` and the edge between the helper and the prompt), [arc42 section 5](../arc42/05-building-block-view.md) (what spike 0120 changed in the model) and [section 8](../arc42/08-crosscutting-concepts.md) (a "forged presence or verification" threat next to "silent use").

**Credential Index (requirements).** Kept by the Agent, one record per resident credential: handle (random, the credential ID), relying-party id and hash, user `id`, `name` and `displayName`, provider, creation time, the wrapped key blobs; a record for the same relying party and user id replaces the earlier one. It answers a `get` with no allow list and resolves handles in an allow list. The credential ID of a resident key carries no key material. User details are returned only when the user was verified. Not covered: credential management, deleting, the migration when the PIN changes, how a second provider's credentials enter it.

**Prompt UI (requests).** One prompt and one gesture per request. Shows the relying-party id from the request and credential labels from the Index, never client text (user names are text the relying party chose: shown only in the chooser, after sanitising). Presence is a gesture the session cannot synthesise; the prompt never carries the decision when the gesture is a sensor. A choice among credentials or providers is a separate, non-authorising step. Started by the Agent's side with its own AppArmor profile, not dumpable; the Agent checks the peer's label.

**Agent (requests).** `getInfo.uv` true only when satisfiable; the silent probe answered without the key; Chromium's `.dummy` and Firefox's `make.me.blink` `makeCredential` treated as selection probes; keepalives while waiting; `CHANNEL_BUSY` for other channels; the 60 s cap a constant, not configuration; a policy class `presence` (click) is the degraded class, the default is the verifying class because the PIN always exists.

**Input for ADR-0020 (#139).** Presence from a sensor or PIN; UV rule as tested; the prompt confined; one prompt and one signature per ceremony. The tests named on #139 map to: `signature_without_a_sensor_gesture_is_refused_when_policy_requires_it` (C, sensor Agent), `uv_flag_is_set_only_after_verification_for_this_request` (A), `repeated_assertion_for_one_ceremony_prompts_once` (A and B).

### Open for ADR-0020

1. **UV from the window with a click for presence.** Inside the window a click is enough for UV=1, and a synthetic click gives the same. The window then adds exposure and no assurance on a machine with a sensor, because a sensor match is already a verification. Recommendation to weigh: count the window only when presence is itself a gesture the session cannot synthesise, or drop the window for click-only presence. This is the maintainer's decision on the ADR; the 60 s cap holds either way.
2. **A PIN typed into an X11 prompt is observable.** Prefer the sensor; keep the PIN prompt for machines without one and say what it does not stop; Wayland to be tested.
3. **AppArmor does not stop an unconfined tracer of the same user.** Not-dumpable (and Yama) do. The profile still gives the file and network confinement, the scrubbing of preload and the label the Agent checks. Whether the installation must require `ptrace_scope` of 1 or only rely on not-dumpable is for the ADR; other distributions were not tested.
4. **The prompt as the Agent's child does not carry over** (above). The ADR should say what authenticates the prompt in the real design.

## Reproducing the evidence

```sh
make vm-up                      # once
make vm-test-uvup               # sections A, B, C: about 12 minutes (62 s of it waiting for the cap)
LH_UVUP_SECTIONS="D" make vm-test-uvup    # Chrome stable and the Snaps (downloads about 600 MB)
LH_UVUP_QUICK=1 make vm-test-uvup         # skip the cap wait and the browser matrix
```

The first run installs packages, Playwright's Chromium and Firefox and python-fido2 in the VM. Source: [scripts/spike-0120](https://github.com/LinuxHello/linux-hello-workstation/tree/main/scripts/spike-0120) (`lhctap2.py`, `lh-prompt-stub` and its profile, `remote-uvup.sh` with every check).
