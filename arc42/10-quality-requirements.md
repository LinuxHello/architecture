---
type: architecture
subject: "Arc42 section 10: quality requirements of Linux Hello (how secure, available, fast and clear it must be, and how each is checked)"
artifact: arc42-10-quality-requirements
status: active
owner: "@atterdag"
concepts: [quality, security-properties, performance-budgets, arc42]
tags: [architecture, arc42]
sources: ["README.md", "12-glossary.md", "01-introduction-and-goals.md", "../adr/0020-presence-and-verification.md", "../adr/0023-pam-module-and-login-failure.md", "../spikes/0094-virtual-ctap-end-to-end.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md", "https://docs.arc42.org/section-10/"]
date: 2026-11-17
---

# 10. Quality requirements

Part of the [Arc42 architecture documentation](README.md).

This section answers the question: how good must Linux Hello be, and how will anyone know? [Section 1.3](01-introduction-and-goals.md#13-quality-goals) names four quality goals in order of importance: security, availability at login, speed and usability. This section turns each goal into checks that can pass or fail: a statement with a test, a failure with its expected outcome, or a time with a limit. Terms that may be new to you are in the [glossary](12-glossary.md).

## 10.1 The four goals and how each is checked

When two goals conflict, the higher one wins. The table shows where the checks for each goal are.

| Rank | Goal | Checked by |
| :-- | :-- | :-- |
| 1 | **Security**: the PIN is the root of trust, nothing quietly weakens how the user is checked, and another program of the same user cannot fake the user's presence | The [security properties](12-glossary.md#property-security-property): plain statements, each with a test named after it ([10.2](#102-security-the-security-properties)) |
| 2 | **Availability at login**: a failure of Linux Hello never locks the user out of their own computer | Three failure scenarios, A1 to A3 ([10.3](#103-availability-what-happens-when-something-fails)) |
| 3 | **Speed**: signing in is quick enough that nobody turns Linux Hello off | Five time budgets, L1 to L5 ([10.4](#104-speed-time-budgets)) |
| 4 | **Usability**: the user always sees which method is running and what to do next | The requirements UX1 to UX8 in [section 8, User experience](08-crosscutting-concepts.md#user-experience) |

An example of the order at work: security ranks above availability, yet the account password still works when Linux Hello fails. The two fit because the password only logs the user in; it never unlocks the keys in the TPM, so a login by password leaves every passkey locked.

## 10.2 Security: the security properties

Security is checked through *security properties*. A property is one sentence a reader can understand without code, such as "a request for one website is never answered with another website's passkey", together with the name of the test that proves it. Writing the test's name first means a property cannot be claimed without a way to check it.

The properties live with the code, in [`docs/security/` of linux-hello](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md):

- **Planned properties:** 27 statements, each with the name of its test and the part that owns it. Most of those tests are placeholders, marked to be skipped, until the part they test is built.
- **Properties that already hold:** the index lists the properties that have a passing test or a CI job today, for example that `unsafe` Rust code exists only in the allowed modules of the TPM provider and the PAM module.

The threat model in the same folder says which attacks the properties answer. [Section 8](08-crosscutting-concepts.md#security-hardening) summarises it.

## 10.3 Availability: what happens when something fails

These three scenarios describe a failure and what the user must see. They follow from the rule that a broken Linux Hello must never lock anyone out ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)).

| Id | When this happens | The user sees | Checked by | State |
| :-- | :-- | :-- | :-- | :-- |
| A1 | The PAM module cannot reach the Agent | Within 250 milliseconds the PAM module gives up and the password prompt appears | The test `pam_returns_within_its_deadline_when_the_agent_hangs`, part of the PAM module ([linux-hello#196](https://github.com/LinuxHello/linux-hello/issues/196)) | Not built |
| A2 | fprintd or Howdy is missing | That method is not offered, and the PIN prompt appears with no delay | A budget check ([linux-hello#211](https://github.com/LinuxHello/linux-hello/issues/211)) | Not built |
| A3 | Linux Hello is unavailable at login, at the lock screen or for `sudo` | The PAM module answers "cannot decide" (`PAM_AUTHINFO_UNAVAIL`), and the account password still works | The test `login_falls_through_to_the_account_password_when_linux_hello_is_unavailable` and runs in a virtual machine ([linux-hello#198](https://github.com/LinuxHello/linux-hello/issues/198)) | Not built; the PAM configuration that makes it possible is built |

## 10.4 Speed: time budgets

A time budget is the longest a step may take. The budgets below are **targets**: none is measured yet. A budget becomes a requirement once a check measures it and passes; from then on the check fails whenever a change makes the step slower than its budget.

The only measurement so far comes from an experiment: a full passkey sign-in with a software TPM took 0.5 to 1.0 seconds, with one process started per TPM command ([spike 0094](../spikes/0094-virtual-ctap-end-to-end.md)). The real implementation will talk to the TPM from inside one process, so it should be faster.

| Id | Step | Budget | Checked by | State |
| :-- | :-- | :-- | :-- | :-- |
| L1 | A call to the Agent, such as asking for the state of a sign-in attempt (`GetState`, `ReportState`); 99 of 100 calls must finish within the budget | 5 ms | A benchmark | Not measured. The work on the Agent's request path ([linux-hello#150](https://github.com/LinuxHello/linux-hello/issues/150)) is closed, but no benchmark exists yet |
| L2 | From the moment PAM starts to the moment the prompt shows which method is running | 200 ms | [linux-hello#207](https://github.com/LinuxHello/linux-hello/issues/207) | Not measured |
| L3 | Fingerprint unlock, from the touch to the open session | 1 s | [linux-hello#208](https://github.com/LinuxHello/linux-hello/issues/208) | Not measured |
| L4 | Face unlock, from opening the laptop lid to the open session | 2 s | [linux-hello#209](https://github.com/LinuxHello/linux-hello/issues/209) | Not measured |
| L5 | A passkey sign-in on a hardware TPM, from the browser's request to the signature, not counting the time the user takes to touch the sensor | 700 ms | [linux-hello#210](https://github.com/LinuxHello/linux-hello/issues/210) | Not measured; never tried on a hardware TPM |

## 10.5 Not covered yet

Two qualities have no scenario: **maintainability**, how easy the code is to change, and **resource use**, how much memory and processor time the Agent takes while it waits. Both are gaps; nothing is invented to fill them.
