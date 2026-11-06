---
type: spike
subject: Change the TPM root key's authorisation in place with tss-esapi
artifact: spike
status: open
owner: "@atterdag"
concepts: [tpm, tss-esapi, pin, change-auth, swtpm]
tags: [spike, m0]
sources: []
date: 2026-11-06
issue: https://github.com/LinuxHello/linux-hello/issues/11
---

# Spike: Change the TPM root key's authorisation in place with tss-esapi

## Question

Can tss-esapi change the authorisation of the per-user TPM root key in place (`TPM2_ObjectChangeAuth` or equivalent) without re-creating the key or its children?

## Time box

Proposed: 2 working days. Stop at the time box and record what is known.

## Method

Read tss-esapi at the version we would pin; prototype against swtpm in CI, then a hardware TPM; confirm child keys still load after the change.

Nothing has been run for this note yet. Mark each command and script tested or untested, with versions and hardware class, when the spike is run.

## Blocks

Changing the PIN must be non-destructive; only 'forgot PIN' leads to the destructive reset ([ADR-0003](../adr/0003-destructive-reset.md)). Blocks PIN change in the Agent and `linuxhello-ctl`.

## Evidence

None yet. The spike is open.

## Answer

Open. Fill in Yes / No / Partly here, and link the ADR or issue the answer changes.
