---
type: architecture
subject: "Arc42 section 8, policy: the rules that decide which methods, which key store and how strong a prompt each situation and website needs, and who may set them"
artifact: arc42-08-policy
status: active
owner: "@atterdag"
concepts: [policy, routing-policy, windows-hello-for-business, arc42]
tags: [architecture, arc42, policy]
sources: ["08-crosscutting-concepts.md", "12-glossary.md", "../adr/0014-agent-bus.md", "../adr/0018-user-policy-layer.md", "../adr/0023-pam-module-and-login-failure.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md", "https://github.com/LinuxHello/linux-hello/blob/main/policy/policy.example.toml"]
date: 2026-11-17
---

# 8. Crosscutting concepts: policy

Part of [section 8](08-crosscutting-concepts.md) of the [Arc42 architecture documentation](README.md).

This note answers the question: who decides which sign-in methods are allowed, where a website's passkey is kept, and how strict Linux Hello is? The answer is the [routing policy](12-glossary.md#policy-routing-policy): a set of rules in text files that the Agent reads before every sign-in and every passkey request. The rules mirror the settings companies use for Windows Hello for Business, set there through Group Policy or Microsoft Intune, and add rules per situation and per website. After reading this note you know who asks the policy what, how the layers of rules combine, and which settings exist. The exact rules, precise enough to implement and test, are in the [policy semantics](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md). Terms that may be new to you are in the [glossary](12-glossary.md).

## One question before every operation

The part of the Agent that holds the rules, the Routing Policy Engine, answers one question: for this situation, this caller and this website, which methods are allowed, which key store may hold the passkey, and how strong must the prompt be? A *situation*, called a [context](12-glossary.md#context) in the policy, is one of `login`, `unlock`, `sudo` and `session` (using passkeys during a session).

| Who asks | What it asks | What it gets back |
| :-- | :-- | :-- |
| The Method Orchestrator in the Agent, which runs the methods for a sign-in that the PAM module opened ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)) | Which methods are allowed in this context | The methods, and how many must succeed |
| The Virtual CTAP Authenticator and the providers, for a passkey request | The decision for this website and this operation, creating a passkey or using one | The key store (TPM, KeePassXC or either), the prompt level and the number of factors |
| The Auth Prompt and the Prompt UI | Which methods to offer and let the user switch between | The method list, and which options are locked |
| The PIN Manager | The PIN rules | Length, character rules and the lockout limits |
| The settings page | The effective policy, and which settings the administrator manages | The values, each marked if it is managed |

The *prompt level* says how much the user must do for a website: `none` (the unlocked session is enough), `presence` (the user confirms they are there) or `reverify` (the user proves who they are again).

## Three layers of rules

The rules come in three layers, applied in this order:

1. **Built-in defaults**, in the Agent. For example: a PIN of at least six characters with digits; five wrong PINs lock the user for 15 minutes; every website's passkey is kept in the TPM.
2. **The user's layer**, for the user's own choices. The Agent keeps it in `/var/lib/linuxhello/users/<uid>/policy.toml`, and the user changes it through the Agent's D-Bus calls `GetUserPolicy` and `SetUserPolicy`, from the settings page or, later, with `linuxhello-ctl policy edit`. It can only make a default stricter, never weaker ([ADR-0018](../adr/0018-user-policy-layer.md)). The file is not in the user's home directory, because then any program of the user could change it, and the Agent would have to read home directories.
3. **The administrator's layer**, in `/etc/linuxhello/policy.d/*.toml`, owned by root and readable by all. A setting there wins over the user's, and the settings page shows it greyed out as "Managed by your organisation". Later a device-management system could deliver these files, as Intune does for Windows.

When two of the administrator's files disagree, the stricter value wins.

**The policy fails closed.** If a policy file cannot be trusted, because it does not parse, cannot be read, or could be changed by someone other than its owner, the engine does not guess. It enters the [PIN-only state](12-glossary.md#pin-only-state): only the PIN works, and fingerprint and face are off. If only the user's layer is at fault, the administrator's rules still apply, so a broken or hostile user file can never lower an administrator's rule. That last rule is the amendment of [ADR-0018](../adr/0018-user-policy-layer.md) of 2026-11-10, which is still proposed but already built ([policy semantics, fail closed](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md#fail-closed)).

## The settings

| Group | Setting | What it does | Windows Hello for Business equivalent |
| :-- | :-- | :-- | :-- |
| PIN | `min_length`, `max_length` | Shortest and longest PIN | Minimum and maximum PIN length |
| PIN | `digits`, `lowercase`, `uppercase`, `special` | Whether each kind of character is `required`, `allowed` or `disallowed` | Digits, lowercase, uppercase and special characters |
| PIN | `history`, `expiry_days` | How many earlier PINs may not be reused; after how many days the PIN must change | History, expiration |
| PIN | `lockout_attempts`, `lockout_minutes` | How many wrong PINs lock the user, and for how long. These set the Agent's own count per user; Linux Hello never changes the TPM's own limits, which are shared by all users | The TPM's protection against guessing |
| Methods | `biometrics_allowed` | Whether fingerprint and face may be used at all | Allow use of biometrics |
| Methods | `face_requires_ir` | Only a face seen by an infrared camera counts, which a photograph cannot fool as easily | Enhanced anti-spoofing |
| Methods | `require_hardware_tpm` | Refuse a TPM emulated in software | Use a hardware security device |
| Context | `methods`, `factors`, `reverify_after` | Per situation: which methods are allowed, how many must succeed, and after how long the user must prove who they are again | None; Linux Hello's own addition |
| Website | `provider`, `prompt`, `factors`, `require_second_credential` | Per website or group of websites: the key store (`tpm`, `keepassxc` or `any`), the prompt level, how many methods must succeed, and whether a second passkey must exist so a lost one can be replaced | None; Linux Hello's own addition |

## An example

This is an administrator's file, from `policy/policy.example.toml` in linux-hello. It requires a PIN of at least six characters with a digit, allows only the PIN for `sudo`, asks again for a face, fingerprint or PIN after eight hours at the lock screen, and holds every subdomain of `bank.example` to the TPM with two methods, for example a fingerprint and the PIN.

```toml
[pin]
min_length = 6
digits = "required"
special = "allowed"
lockout_attempts = 5

[methods]
biometrics_allowed = true
face_requires_ir = true

[context.sudo]
methods = ["pin"]

[context.unlock]
methods = ["face", "fingerprint", "pin"]
reverify_after = "8h"

[rp_class.banking]
match = ["*.bank.example"]
provider = "tpm"
factors = 2          # e.g. fingerprint + PIN
require_second_credential = true
```

## What exists today

Built and tested: the schema and its strict parsing (any unknown key makes a file unparseable, and a test parses the example above), the three layers and how they combine, the PIN-only state, and the user's layer with `GetUserPolicy` and `SetUserPolicy`. Not built: anything that acts on the answers, because the parts that would ask, such as the Method Orchestrator and the providers, do not exist yet. The comment at the top of the example file still calls the key names proposals; until a release, they may change.
