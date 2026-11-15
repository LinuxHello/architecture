---
type: adr
subject: User presence is a gesture the session cannot synthesise, and user verification is tied to a request or a window of at most 60 seconds
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [webauthn, ctap, user-presence, user-verification, prompt-ui, apparmor, threat-model]
tags: [adr, security, browser]
sources: ["0017-browser-path.md", "../spikes/0094-virtual-ctap-end-to-end.md", "../spikes/0120-resident-keys-presence-and-uv.md", "https://github.com/LinuxHello/linux-hello/issues/139"]
date: 2026-11-15
---

# ADR-0020: Presence and verification that a process of the same user cannot forge

## Status

Proposed, 2026-11-15. Amends [ADR-0017](0017-browser-path.md), decision item 1 and the "silent use" consequence. Answers [issue 139](https://github.com/LinuxHello/linux-hello/issues/139), on the evidence of [spike 0120](../spikes/0120-resident-keys-presence-and-uv.md). The maintainer decided on 2026-11-15 that this issue closes on a decision first, and that the verification window is a hard cap of 60 seconds. The four open points at the end are for the maintainer.

## Context

ADR-0017 makes the presence prompt the only barrier between a local process that can open the HID node and a signature. The threat model's actor M2 is a malicious process running as the user. The plan also mapped "session unlocked" to the CTAP user-verification (UV) flag, so a relying party could receive UV=1 for an assertion nobody verified, hours after login.

Spike 0120 tested the mechanism on a software TPM, with a Tk stub for the prompt, under X11:

- A click on an Allow button is **not** presence against M2: synthetic input produces a signature, also when the prompt is confined under AppArmor.
- A sensor match delivered to the Agent, or a PIN checked by the TPM, produces no signature from synthetic input, from an impostor prompt, from `ptrace` or from preload.
- Presence, UV and one signature per request all work in Chromium, Chrome stable and Firefox, including the Snap builds.
- Firefox sends a silent probe (`getAssertion` with `up=false`) before the real request; answering it without the key gives one prompt and one signature per `get`.
- A PIN typed into a prompt under X11 is readable by another X client of the same user.

## Decision

1. **Presence is a gesture the session cannot synthesise:** a fingerprint match delivered through fprintd to the Agent, or the PIN typed into the prompt and checked by the TPM. When a sensor exists, the sensor decides; the prompt only displays and carries no decision. A click-only prompt exists only for policy classes with `prompt = "presence"` on a machine without a sensor, and the documentation says what it does not stop: any process of the same user can press it.
2. **UV=1 only for a verification of this request, or within a window of at most 60 seconds** after a verification event, and only for a request that asks for UV. The 60 seconds are a **hard cap, a constant in the code**: policy may shorten it, never raise it. A click is never a verification. `getInfo` advertises `uv` only when it can be satisfied. "Session unlocked" no longer maps to UV.
3. **The prompt process is confined:** its own AppArmor profile, not dumpable, no `ptrace`. It shows the relying-party id taken from the request and, for a choice, credential labels from the Credential Index, never other text from the client. The Agent accepts it only if it is the process the Agent expects, checked by its AppArmor label.
4. **One prompt, one gesture and one signature per request.** A `getAssertion` with `up=false` is answered without the key (a well-formed response that does not verify, no counter increment), and the selection probes (`makeCredential` for `.dummy` and `make.me.blink`) are refused without a prompt. With several credentials the Prompt UI asks which one, so one signature is made; otherwise `numberOfCredentials` is not offered.
5. **Names the tests will use** (each is a property in `docs/security/properties.md`, written in the code issues #173 to #176 after this ADR is accepted): `signature_without_a_sensor_gesture_is_refused_when_policy_requires_it`, `uv_flag_is_set_only_after_verification_for_this_request`, `repeated_assertion_for_one_ceremony_prompts_once`.

## Consequences

**Easier:** one rule for what counts as presence; no signature without a gesture a same-user process cannot make, on a machine with a sensor or a PIN; the Prompt UI keeps few responsibilities.

**Harder:**

- A machine without a sensor depends on the PIN, which an X client of the same user can observe under X11. Wayland was not tested.
- A click-only class stays forgeable by M2 and is a degraded class. Chromium waits and Firefox ignores UV when `uv` is not advertised, so that class also breaks sites that require UV.
- Three wrong PINs typed through the prompt lock the TPM (a denial of service, not a forgery); the per-user counter of [#137](https://github.com/LinuxHello/linux-hello/issues/137) is where this is limited.
- The pid check used for the prompt in the spike does not carry over to a prompt started in the user's session. What carries over: with a sensor the decision never passes through the prompt, and with a PIN the TPM checks it.
- Not tested: a hardware TPM, fprintd and a real sensor, the QML prompt, Flatpak browsers, Firefox as a `.deb`, a real relying party, other distributions.

**Follow-up:** the four code issues [#173](https://github.com/LinuxHello/linux-hello/issues/173) (sensor gesture), [#174](https://github.com/LinuxHello/linux-hello/issues/174) (UV window), [#175](https://github.com/LinuxHello/linux-hello/issues/175) (confined prompt) and [#176](https://github.com/LinuxHello/linux-hello/issues/176) (one prompt per ceremony), unblocked when this ADR is accepted; the threat-model rows (actor M2, T5 "silent use") in the linux-hello repository change in the pull request that bumps the pin.

## Open points for the maintainer

Each has a recommendation; the Decision above stands as written unless you choose otherwise.

1. **Does the window count when presence is a click?** Inside the window a click gives UV=1, and a synthetic click gives the same. *Recommendation:* count the window only when presence is a gesture the session cannot synthesise; with click-only presence UV is per request or not offered.
2. **PIN prompt on X11.** *Recommendation:* prefer the sensor; keep the PIN for machines without one and document what it does not stop; test Wayland before 1.0.
3. **`ptrace`.** AppArmor alone does not stop an unconfined tracer of the same user; not-dumpable and Yama do. *Recommendation:* require not-dumpable in the prompt, document `ptrace_scope` 1 (the Ubuntu default) as expected but not required; test other distributions later.
4. **What authenticates the prompt when it runs in the user's session.** *Recommendation:* a short spike before the confined-prompt issue (#175) is briefed.
