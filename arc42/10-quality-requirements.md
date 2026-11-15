---
type: architecture
subject: "Arc42 section 10: quality requirements of Linux Hello"
artifact: arc42-10-quality-requirements
status: draft
owner: "@atterdag"
concepts: [quality, security-properties, arc42]
tags: [architecture, arc42]
sources: ["README.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md", "https://docs.arc42.org/section-10/"]
date: 2026-11-05
---

# 10. Quality requirements

Part of the [Arc42 architecture documentation](README.md).

## 10.1 Quality requirements overview

The goals of [section 1.2](01-introduction-and-goals.md#12-quality-goals), as a tree:

- **Security** (rank 1): the security properties.
- **Availability at login** (rank 2): scenarios A1 to A3.
- **Speed** (rank 3): scenarios L1 to L5.
- **Usability** (rank 4): UX1 to UX8.

## 10.2 Quality scenarios

The security properties in [docs/security/](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md) are the testable scenarios for security: each is a plain-language statement with the test or CI job that checks it. The usability requirements UX1 to UX8 are in [section 8, User experience](08-crosscutting-concepts.md#user-experience).

The budgets below are **targets**. None is measured yet, except the software-TPM ceremony time of [spike 0094](../spikes/0094-virtual-ctap-end-to-end.md) (0.5 to 1.0 s with one process per TPM command). A budget becomes a requirement when its check exists and passes; the check fails on regression. Two rows are marked as targets with a known dependency: L1 needs the request-path work of [#150](https://github.com/LinuxHello/linux-hello/issues/150) before 5 ms is reachable, and L5 has never been measured on a hardware TPM.

| Id | Scenario | Budget | Check |
| :-- | :-- | :-- | :-- |
| L1 | Agent method call (`GetState`, `ReportState`), p99 | 5 ms (target, not yet measured) | Benchmark in [#150](https://github.com/LinuxHello/linux-hello/issues/150) |
| L2 | Prompt indicator visible after PAM start | 200 ms | [#207](https://github.com/LinuxHello/linux-hello/issues/207) |
| L3 | Fingerprint unlock, touch to session | 1 s | [#208](https://github.com/LinuxHello/linux-hello/issues/208) |
| L4 | Face unlock, lid open to session | 2 s | [#209](https://github.com/LinuxHello/linux-hello/issues/209) |
| L5 | Passkey assertion, request to signature, excluding the user's gesture, hardware TPM | 700 ms (target, not yet measured) | [#210](https://github.com/LinuxHello/linux-hello/issues/210) |
| A1 | PAM gives up on an unreachable Agent | 250 ms | `pam_returns_within_its_deadline_when_the_agent_hangs` in [#196](https://github.com/LinuxHello/linux-hello/issues/196) |
| A2 | fprintd or Howdy missing | The method is not offered; the PIN prompt appears with no delay | [#211](https://github.com/LinuxHello/linux-hello/issues/211) |
| A3 | Linux Hello unavailable at login, unlock or `sudo` | `PAM_AUTHINFO_UNAVAIL`; the account password still works | `login_falls_through_to_the_account_password_when_linux_hello_is_unavailable` and the VM runs of [#198](https://github.com/LinuxHello/linux-hello/issues/198) |

**Gap.** Maintainability and resource use (memory and CPU of the Agent) have no scenario yet.
