---
type: spike
subject: Binding each TPM credential key to its relying party inside the TPM
artifact: spike
status: answered
owner: "@atterdag"
concepts: [tpm, credential, relying-party, p-03, hmac, authorisation, noda]
tags: [spike, m0]
sources: ["0094-virtual-ctap-end-to-end.md", "0011-tpm-root-key-change-auth.md", "https://trustedcomputinggroup.org/resource/tpm-library-specification/"]
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/119
---

# Spike: Binding each TPM credential key to its relying party inside the TPM

## Question

How is each TPM credential key made unusable for any relying party other than the one it was created for, inside the TPM and not only in the helper's code?

## Time box

Proposed two working days; done in one session, one option tried.

## Method

The test VM from `make vm-up` (Ubuntu 24.04.5, swtpm 0.10.1, `tpm2-tools` 5.6). Script: `make vm-test-rpbind` in `linux-hello-workstation` (`scripts/vm-test-rpbind.sh`), **tested** on 2026-11-08.

**Option tried: the key's authorisation value is derived from the relying party by the TPM.** Under the per-user root key R (PIN-protected, [spike 0011](0011-tpm-root-key-change-auth.md)) there is one HMAC key H per user. For a relying party the authorisation value is `HMAC-SHA256(H, SHA-256(rpId))`, computed by `TPM2_HMAC` inside the TPM. A credential key is created as a child of R with that value as its `authValue`, with the attributes `fixedTPM|fixedParent|sensitiveDataOrigin|userWithAuth|noDA`. To sign, the helper loads the key under R (PIN), asks H for the value of the relying party named in the request, and presents it. A request for another relying party yields another value, and the TPM refuses the signature.

**Not tried (untested):** a key authorisation *policy* (`PolicyAuthValue` or `PolicySecret` over an RP-keyed value); the relying-party hash in the sealed data (the TPM would not enforce it); a derived child key per relying party (`TPM2_CreateLoaded` with a derivation parent).

## Evidence

All checks passed (11 PASS, `ALL PASSED`):

| Check | Result |
| :-- | :-- |
| H gives different values for `example.test` and `other.test`, and the same value twice for one | yes |
| The credential key signs with its own relying party's value | yes, `tpm2_sign` exit 0 |
| The same key with the other relying party's value | refused by the TPM (authorisation failure), no signature written |
| The same key with no value | refused |
| Lockout counter after the refused request on a key with `noDA` | unchanged (0) |
| Control: the same refused request on a key **without** `noDA` | counter 0 → 1 |
| PIN change in place (`tpm2_changeauth` on R, new blob) | the credential still loads under the new R and signs; H still gives the same value |

Sizes and times (swtpm, one `tpm2-tools` process per call): create 84 to 92 ms, sign about 120 ms. A credential is a public blob of 90 bytes and a private blob of 128 bytes (218 bytes, within the 1023 a CTAP credential ID may have). H exists once per user: public 50 bytes, private 160 bytes, stored beside the root key, not in each credential.

## Answer

**Yes**, on a software TPM, for this option: a credential key is unusable for any relying party but its own because the TPM refuses the authorisation value of another, and a refused request does not count towards the dictionary-attack lockout provided the key carries `noDA`.

What it does and does not protect:

- **A helper bug or a lookalike hash cannot sign for the wrong site.** The 4-byte tag of [spike 0094](0094-virtual-ctap-end-to-end.md) is no longer the guard; the TPM is. This gives P-03 (a request for one relying party is never answered with another's credential) a TPM-enforced form.
- **A compromised helper is not stopped.** The helper names the relying party; if it lies, it receives that site's value and signs for that site with a key of that site only. It cannot make a key of site A sign for site B. What it can do is use A's key for A's requests, which it already could by being the helper.
- **`noDA` is required on credential keys** so that a refusal for the wrong site does not lock the user out. The root key R keeps dictionary-attack protection, which is where the PIN is guarded.
- **The PIN change is unaffected:** H and every credential are children of R and keep working under the new blob (and the old blob keeps working with the old PIN, as in spike 0011).

Costs and limits: one more TPM command (`TPM2_HMAC`) per create and per sign; the root key's blob set now includes H; the 4-byte tag in the credential ID can be dropped. Tested only on swtpm with `tpm2-tools`; a hardware TPM and `tss-esapi` were not tried, and the policy-based options were not compared.

Consequences for the design: the TPM Key Service (`tpmKeys`) creates H with R and derives the value per request; the Credential Index (`credStore`) keeps the relying-party id beside each credential; the test for P-03 (`credential_for_another_relying_party_is_never_returned`) can ask the TPM, not the code, for the refusal.
