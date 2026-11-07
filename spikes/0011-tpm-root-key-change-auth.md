---
type: spike
subject: Change the TPM root key's authorisation in place with tss-esapi
artifact: spike
status: answered
owner: "@atterdag"
concepts: [tpm, tss-esapi, pin, change-auth, swtpm]
tags: [spike, m0]
sources: ["https://docs.rs/tss-esapi/7.7.0/tss_esapi/struct.Context.html#method.object_change_auth", "https://trustedcomputinggroup.org/resource/tpm-library-specification/"]
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/11
---

# Spike: Change the TPM root key's authorisation in place with tss-esapi

## Question

Can tss-esapi change the authorisation of the per-user TPM root key in place (`TPM2_ObjectChangeAuth` or equivalent) without re-creating the key or its children?

## Time box

Proposed: 2 working days. Stop at the time box and record what is known.

## Method

Read tss-esapi at the version we would pin; prototype against swtpm in CI, then a hardware TPM; confirm child keys still load after the change.

What was run (**tested**, one run, 2026-11-08):

- **Software TPM:** swtpm 0.10.1, TPM 2.0, started with `swtpm socket --tpm2 --tpmstate dir=<d> --server type=tcp,port=2321 --ctrl type=tcp,port=2322 --flags not-need-init,startup-clear`.
- **Library:** `tss-esapi` 7.7.0 (the newest stable release; `cargo add tss-esapi@7.6.0` resolved to it) with `tss-esapi-sys` 0.6.0 against the system TSS2 4.1.3 (`libtss2-dev`), Rust 1.99.1, Ubuntu 26.04, kernel 7.0.0-43. Install the build dependencies with `make tpm-dev-deps` in `linux-hello-workstation`.
- **Prototype:** the program in the appendix. It creates a storage primary P under the owner hierarchy (RSA 2048, like an SRK), a per-user root key R as an ordinary child of P with authorisation `pin-old`, and a signing key C (ECC P-256) as a child of R. It then calls `Context::object_change_auth` on R to set `pin-new`, and checks what still works. Password sessions were used, so the authorisation values crossed the TCTI socket in clear; a real implementation uses HMAC sessions with parameter encryption.

**Untested:** a hardware TPM; `tss-esapi` 8.0.0-alpha.4; a persistent R (`TPM2_EvictControl`); HMAC and policy sessions; the dictionary-attack settings of a real TPM; running the change after a reboot or from the Agent process.

## Blocks

Changing the PIN must be non-destructive; only 'forgot PIN' leads to the destructive reset ([ADR-0003](../adr/0003-destructive-reset.md)). Blocks PIN change in the Agent and `linuxhello-ctl`.

## Evidence

Output of the appendix program, in order (abridged `esys` log lines removed):

```text
created P (primary) and R (root key, auth 'pin-old')
created C (signing key) under R
[ok]   baseline: load R with 'pin-old', load C under it, sign
[ok]   wrong PIN: R loaded under 'pin-wrong' cannot be used (refused: the authorization HMAC check failed and DA counter incremented (associated with session number 1))
[ok]   ObjectChangeAuth(R: 'pin-old' -> 'pin-new') returned a new private blob
[ok]   after change: load R' with 'pin-new', the old child C loads under it and signs
[ok]   after change: R' with the OLD PIN cannot be used (refused: the authorization HMAC check failed and DA counter incremented (associated with session number 1))
[ok]   after change: the OLD blob R with the OLD PIN still works (no revocation)
ObjectChangeAuth on the primary P: rejected: value is out of range or is not correct for the context (associated with handle number 2)
```

What this shows:

1. **The change is in place for the children.** `object_change_auth` returns a new private blob for R under the same parent. The child C created under the old R loaded under the new R and produced a signature, so no passkey key has to be re-created.
2. **The PIN is checked when R is used as a parent**, here when loading C under it. R itself loads under P without its own authorisation. A wrong PIN is refused by the TPM and increments the dictionary-attack counter, so the TPM's anti-hammering applies to PIN guesses ([arc42 section 8](../arc42/08-crosscutting-concepts.md)).
3. **The old PIN does not stop working for the old blob.** The change produces a new blob; the old blob and the old PIN are still valid against the same TPM. A copy of the old blob (a backup, a snapshot) keeps unlocking every child under it. The PIN change must therefore delete the old blob, and it does not revoke anything an attacker already copied.
4. **A primary key cannot be changed this way.** `object_change_auth` on P was refused. The per-user root key has to be an ordinary child of a primary (as R is here), not a primary derived from the hierarchy seed with the PIN in its template.

## Answer

**Yes**, with two conditions, on a software TPM.

The authorisation of the per-user root key can be changed in place with tss-esapi, and its children keep loading, **provided the root key is created as a child of a storage primary**. That makes the non-destructive PIN change of [arc42 section 8](../arc42/08-crosscutting-concepts.md) possible and leaves the destructive reset ([ADR-0003](../adr/0003-destructive-reset.md)) for a forgotten PIN only.

Conditions and consequences for the design:

- **Root key shape.** R is a non-primary storage key, with its blob stored by the Agent; do not use a primary as the root key.
- **No revocation.** Deleting the old blob is the only revocation. If a changed PIN must also defeat a leaked old PIN together with a copied old blob, R needs an authorisation policy that ties it to something that changes, for example a policy on an NV counter that the change increments. That was not tried and needs its own check.
- **Sessions.** Use HMAC sessions with parameter encryption; the prototype did not.

Not covered: hardware TPM behaviour, dictionary-attack lockout parameters, persistent handles, and the 8.0 alpha of tss-esapi. Re-run the appendix program against a hardware TPM before the PIN-change implementation brief is written.

## Appendix: the prototype

`Cargo.toml`: `tss-esapi = "7.6.0"` (resolved to 7.7.0). `src/main.rs`:

```rust
//! Spike 0011: can the authorisation of a TPM root key be changed in place, with its children still loading?
//! Runs against swtpm on 127.0.0.1:2321 (TCTI "swtpm").
use std::{convert::TryFrom, str::FromStr};
use tss_esapi::{
    constants::{tss::*, StartupType},
    handles::KeyHandle,
    interface_types::{
        algorithm::{HashingAlgorithm, SignatureSchemeAlgorithm},
        ecc::EccCurve,
        key_bits::RsaKeyBits,
        resource_handles::Hierarchy,
    },
    structures::{
        Auth, Digest, EccScheme, HashScheme, HashcheckTicket, Private, Public, RsaExponent,
        SignatureScheme, SymmetricDefinitionObject,
    },
    tss2_esys::{TPM2B_DIGEST, TPMT_TK_HASHCHECK},
    utils::{create_restricted_decryption_rsa_public, create_unrestricted_signing_ecc_public},
    Context, TctiNameConf,
};

type R<T> = Result<T, tss_esapi::Error>;
fn pw(s: &str) -> Auth {
    Auth::try_from(s.as_bytes().to_vec()).unwrap()
}
fn null_ticket() -> HashcheckTicket {
    HashcheckTicket::try_from(TPMT_TK_HASHCHECK {
        tag: TPM2_ST_HASHCHECK,
        hierarchy: TPM2_RH_NULL,
        digest: TPM2B_DIGEST { size: 0, buffer: [0; 64] },
    })
    .unwrap()
}
fn expect_fail(step: &str, r: R<()>) {
    match r {
        Ok(()) => println!("[FAIL] {step}: it worked, it should have been refused"),
        Err(e) => println!("[ok]   {step} (refused: {e})"),
    }
}
fn report(step: &str, r: &R<()>) {
    match r {
        Ok(()) => println!("[ok]   {step}"),
        Err(e) => println!("[FAIL] {step}: {e}"),
    }
}

/// Load `private`/`public` under `parent` with `auth`, run a signature with the child `c`, flush.
fn load_with_auth(ctx: &mut Context, parent: KeyHandle, public: &Public, private: &Private, auth: &str) -> R<KeyHandle> {
    let h = ctx.execute_with_nullauth_session(|c| c.load(parent, private.clone(), public.clone()))?;
    ctx.tr_set_auth(h.into(), pw(auth))?;
    Ok(h)
}

fn main() -> R<()> {
    let tcti = TctiNameConf::from_str("swtpm:host=127.0.0.1,port=2321").unwrap();
    let mut ctx = Context::new(tcti)?;
    let _ = ctx.startup(StartupType::Clear); // swtpm was started with startup-clear; ignore "already started"

    let root_public = create_restricted_decryption_rsa_public(
        SymmetricDefinitionObject::AES_128_CFB,
        RsaKeyBits::Rsa2048,
        RsaExponent::default(),
    )?;
    let sign_public = create_unrestricted_signing_ecc_public(
        EccScheme::EcDsa(HashScheme::new(HashingAlgorithm::Sha256)),
        EccCurve::NistP256,
    )?;

    // P: the storage primary under the owner hierarchy (like the SRK). R: the per-user root key, a child of P, auth = PIN.
    let p = ctx.execute_with_nullauth_session(|c| {
        c.create_primary(Hierarchy::Owner, root_public.clone(), None, None, None, None)
    })?;
    let r = ctx.execute_with_nullauth_session(|c| {
        c.create(p.key_handle, root_public.clone(), Some(pw("pin-old")), None, None, None)
    })?;
    println!("created P (primary) and R (root key, auth 'pin-old')");

    // C: a passkey key under R. Creating it needs R's current auth.
    let r_h = load_with_auth(&mut ctx, p.key_handle, &r.out_public, &r.out_private, "pin-old")?;
    let c = ctx.execute_with_session(Some(tss_esapi::interface_types::session_handles::AuthSession::Password), |ctx| {
        ctx.create(r_h, sign_public.clone(), None, None, None, None)
    })?;
    println!("created C (signing key) under R");
    ctx.flush_context(r_h.into())?;

    let c_blob = (c.out_private.clone(), c.out_public.clone());
    let digest = Digest::try_from(vec![0x42u8; 32]).unwrap();
    let scheme = SignatureScheme::EcDsa { hash_scheme: HashScheme::new(HashingAlgorithm::Sha256) };
    let sign_with = |ctx: &mut Context, root_private: &Private, root_public: &Public, auth: &str| -> R<()> {
        let rh = load_with_auth(ctx, p.key_handle, root_public, root_private, auth)?;
        let ch = ctx.execute_with_session(
            Some(tss_esapi::interface_types::session_handles::AuthSession::Password),
            |c| c.load(rh, c_blob.0.clone(), c_blob.1.clone()),
        );
        ctx.flush_context(rh.into())?;
        let ch = ch?;
        let s = ctx.execute_with_nullauth_session(|c| c.sign(ch, digest.clone(), scheme.clone(), null_ticket()));
        ctx.flush_context(ch.into())?;
        s.map(|_| ())
    };
    report("baseline: load R with 'pin-old', load C under it, sign", &sign_with(&mut ctx, &r.out_private, &r.out_public, "pin-old"));
    expect_fail("wrong PIN: R loaded under 'pin-wrong' cannot be used", sign_with(&mut ctx, &r.out_private, &r.out_public, "pin-wrong"));

    // The change: ObjectChangeAuth(R, parent P, new auth). Needs R's current auth.
    let r_h = load_with_auth(&mut ctx, p.key_handle, &r.out_public, &r.out_private, "pin-old")?;
    let r_new_private = ctx.execute_with_session(
        Some(tss_esapi::interface_types::session_handles::AuthSession::Password),
        |ctx| ctx.object_change_auth(r_h.into(), p.key_handle.into(), pw("pin-new")),
    );
    ctx.flush_context(r_h.into())?;
    let r_new_private = match r_new_private {
        Ok(p) => { println!("[ok]   ObjectChangeAuth(R: 'pin-old' -> 'pin-new') returned a new private blob"); p }
        Err(e) => { println!("[FAIL] ObjectChangeAuth: {e}"); return Ok(()); }
    };

    report("after change: load R' with 'pin-new', the old child C loads under it and signs", &sign_with(&mut ctx, &r_new_private, &r.out_public, "pin-new"));
    expect_fail("after change: R' with the OLD PIN cannot be used", sign_with(&mut ctx, &r_new_private, &r.out_public, "pin-old"));
    report("after change: the OLD blob R with the OLD PIN still works (no revocation)", &sign_with(&mut ctx, &r.out_private, &r.out_public, "pin-old"));

    // Same change on the primary itself: expected not to be possible (a primary has no parent blob).
    let p_try = ctx.execute_with_session(
        Some(tss_esapi::interface_types::session_handles::AuthSession::Password),
        |ctx| ctx.object_change_auth(p.key_handle.into(), Hierarchy::Owner.into(), pw("x")),
    );
    println!("ObjectChangeAuth on the primary P: {}", match p_try { Ok(_) => "ACCEPTED".to_string(), Err(e) => format!("rejected: {e}") });
    let _ = SignatureSchemeAlgorithm::EcDsa;
    Ok(())
}
```
