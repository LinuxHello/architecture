---
type: spike
subject: End-to-end passkey through a virtual CTAP authenticator and the TPM
artifact: spike
status: answered
owner: "@atterdag"
concepts: [ctap, uhid, tpm, webauthn, firefox, chromium, libfido2]
tags: [spike, m0]
sources: ["../adr/0005-provider-path.md", "0011-tpm-root-key-change-auth.md", "https://www.kernel.org/doc/html/latest/hid/uhid.html", "https://fidoalliance.org/specs/fido-v2.0-ps-20190130/fido-client-to-authenticator-protocol-v2.0-ps-20190130.html"]
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/94
---

# Spike: End-to-end passkey through a virtual CTAP authenticator and the TPM

## Question

Can Linux Hello register and authenticate a passkey with unmodified Firefox and Chromium through a virtual CTAP authenticator (`uhid`), with the credential key held under a PIN-protected per-user TPM root key?

## Time box

Proposed: 5 working days. Done in one session as a prototype, so the browsers tried are narrow; see Method.

## Method

**Environment (tested).** The test VM from `make vm-up` in `linux-hello-workstation`: Ubuntu 24.04.5, kernel 6.8.0-147-generic, KVM, a TPM 2.0 from swtpm 0.10.1. In the guest: `tpm2-tools` 5.6, `libfido2-tools` 1.14.0, Python 3 with `cbor2` and `cryptography`, `xvfb`. `uhid` needs `linux-modules-extra` for the running kernel; the VM setup installs it.

**Prototype (tested).** `lhctap.py`, in the appendix. It creates a `uhid` device with the FIDO HID report descriptor (usage page 0xF1D0, 64-byte reports), speaks CTAPHID (`INIT`, `PING`, `WINK`, `CBOR`) and CTAP2 `getInfo`, `makeCredential` and `getAssertion`, and keeps keys in the TPM:

- P: an ECC storage primary under the owner hierarchy (recreated at start).
- R: the per-user root key, a non-primary storage key that is a child of P, authorisation = the PIN ([spike 0011](0011-tpm-root-key-change-auth.md)).
- Each credential: a fresh ECC P-256 signing key, a child of R, created and loaded with R's PIN. The credential ID holds the key's two TPM blobs (229 bytes), so no per-credential file exists. These are non-resident credentials only.
- Attestation is `packed` self-attestation: the credential key signs `authData || clientDataHash`.
- User presence is approved without a prompt; user verification and resident keys are refused (`CTAP2_ERR_UNSUPPORTED_OPTION`).
- The TPM is driven through `tpm2-tools`, not `tss-esapi`.

**Clients (tested).** `fido2-cred` and `fido2-assert` from libfido2 over `/dev/hidraw0`; Chromium 156.0.8078.4 and Firefox 157.0, both Playwright builds, headed under `xvfb-run` as root, driving a local page on `http://localhost:8000/` (secure context) that calls `navigator.credentials.create` and `get` from a button click.

**Untested.** Distribution packages of the browsers (Snap, Flatpak, `.deb`), Chrome stable, a real relying party such as webauthn.io, a hardware TPM, `tss-esapi` and Rust, `clientPin`, discoverable credentials, exclude lists, hotplug, suspend, two requests at once, CTAPHID keepalives, and the Prompt UI.

## Evidence

1. **The device is a FIDO device.** `fido2-token -L` lists `/dev/hidraw0: vendor=0x1209, product=0xf1d0`. `fido2-token -I` reports proto 0x02, caps `cbor, nomsg, nowink`, `FIDO_2_0`, options `nork, up, noplat`.
2. **libfido2 round trip.** `fido2-cred -M ... es256` made a credential; `fido2-cred -V` verified the self-attestation and wrote the public key; `fido2-assert -G` returned an assertion for it; `fido2-assert -V` verified the signature with that public key. The same credential ID for another relying party gave `FIDO_ERR_NO_CREDENTIALS`. (`fido2-cred` could not print an attestation in the `none` format, so the prototype uses `packed` self-attestation; browsers accept both.)
3. **Wrong PIN.** With the daemon started on a wrong PIN the same credential failed (`FIDO_ERR_NO_CREDENTIALS`, the TPM refused to load the key) and the TPM's `TPM2_PT_LOCKOUT_COUNTER` went to 1 (swtpm's `TPM2_PT_MAX_AUTH_FAIL` is 3).
4. **PIN change in place.** `tpm2_changeauth` on R (new blob, same parent) with the credential untouched: the old credential signed with the new PIN, was refused with the old PIN, and the old blob with the old PIN still worked (no revocation), as in spike 0011.
5. **Chromium 156 and Firefox 157.**

| Request | Chromium | Firefox |
| :-- | :-- | :-- |
| `create`, defaults | OK in 1.0 s; `authenticatorAttachment` = `cross-platform`; `getTransports()` empty | OK in 0.6 s; `cross-platform`; transports `["usb"]` |
| `get` with the credential | OK in 0.5 s | OK in 0.6 s; the device log shows two `GetAssertion` signatures per `get` |
| `create` with `residentKey: required` | no result in 45 s (and in an earlier 120 s run) | `NotAllowedError` after 0.1 s |
| `create` with `userVerification: required` | no result in 45 s (and in an earlier 120 s run) | OK in 0.5 s although the device never sets the UV flag |

In the user-verification run the device log shows only a dummy `makeCredential` from Chrome (`rp=.dummy`). The two Chromium cases waited for something the virtual-display run did not show (Chrome's own UI was not captured); Chromium did not return an error.

## Answer

**Yes**, for the transport and the key hierarchy, for non-resident credentials without user verification, with stock clients: a TPM-backed, PIN-rooted credential was created and used by libfido2, Chromium and Firefox through a `uhid` device, and the PIN change of spike 0011 works under it. Option B of [ADR-0005](../adr/0005-provider-path.md) is viable for the first end-to-end test.

**What the Yes does not cover** (review of 2026-11-08). The question also asked for a real site and a Linux Hello unlock gate. The test page was a local one on `localhost`, and presence was approved without any prompt, so neither was tested. Follow-ups: the real-site and browser matrix ([#118](https://github.com/LinuxHello/linux-hello/issues/118)), binding keys to the relying party inside the TPM ([#119](https://github.com/LinuxHello/linux-hello/issues/119)), resident keys, presence and user verification ([#120](https://github.com/LinuxHello/linux-hello/issues/120)), and the helper's privilege and attack surface ([#121](https://github.com/LinuxHello/linux-hello/issues/121)).

What it costs, from this one prototype:

- **Roaming key.** Both browsers report `cross-platform`. Whether `isUserVerifyingPlatformAuthenticatorAvailable()` and passkey-only sign-in flows work was not tested and is expected to fail for sites that require a platform authenticator.
- **No discoverable credentials.** Without resident keys there is no passkey autofill or username-less sign-in. Firefox refused such a request; Chromium waited on its UI. The Credential Index component in the model is where the credential metadata would be kept; that was not built.
- **No user verification, no user presence.** The prototype signs without any prompt, so any local process that can open the HID device gets assertions. distribution udev rules typically let the logged-in user open FIDO `hidraw` nodes, so the real helper must ask the Prompt UI for presence on every request and map the Agent's unlock state to UV. Firefox completed a `userVerification: required` create against a device that never sets UV, so the relying party must check the UV flag; Chromium blocked.
- **Doubled signatures in Firefox.** Two `GetAssertion` signatures per `get`; a per-sign prompt or a PIN attempt would be hit twice unless the helper recognises the repeat.
- **The TPM counts wrong PINs.** A wrong PIN used by the helper increments the dictionary-attack counter; three failures lock swtpm. How the Agent holds the unlock, so the helper never submits a wrong PIN by itself, is open.
- **The prototype does not bind a credential to its relying party.** It tags the credential ID with the first 4 bytes of the relying-party hash and compares those; the TPM key itself signs for any request, and the signature covers whatever hash the request carries. A site that learns a credential ID of another site (or whose hash matches in those 4 bytes) gets a signature from that key. That cannot satisfy P-03 (a request for one relying party is never answered with another's credential). The real helper has to make the key unusable for other sites inside the TPM, for example through the key's authorisation policy or an RP-keyed value in the sealed data, and compare the full hash.
- **Privilege and attack surface (not measured).** The helper needs `/dev/uhid`, which is `root`-only by default, and `/dev/tpmrm0`; the prototype ran as root with no profile. A real helper needs its own AppArmor profile, a bus policy for the Agent, and an answer to what creating an input device lets an attacker do if the helper is compromised (the kernel `uhid` code path, a fake keyboard). That cost is the open part of the issue's method.
- **Per-relying-party routing is invisible to the browser.** There is one virtual device. Which provider answers (a TPM key or a KeePassXC passkey) is decided by the policy behind it, and the browser shows only "security key". Any choice the user must make has to be asked by the Prompt UI, and a request without an allow list (a discoverable credential) needs the helper to search every provider's index.
- **Speed is not a problem.** Create 0.5 to 1.0 s and get 0.5 to 0.6 s with `tpm2-tools` process calls on a software TPM; a hardware TPM and `tss-esapi` were not measured.

Consequences for the design:

- The `Virtual CTAP Authenticator` container is feasible as drawn; its needs are resident keys through the Credential Index, `getInfo` options for UV, presence and UV prompts through the Prompt UI, and one signature per request.
- Browsers are covered without an extension. [ADR-0013](../adr/0013-browser-fallback.md) (own extension and native-messaging host) is not needed to reach the authenticator and should be revisited for what it adds beyond this path, such as a platform-authenticator presentation.
- Re-run on Chrome stable and the distribution Firefox (Snap), on a hardware TPM, and with a real relying party before the first release.

## Reproducing the evidence

Environment as in *Method*; the daemon runs as root in the VM (`sudo -E LH_PIN=123456 python3 lhctap.py`, source in the appendix).

**libfido2 round trip (tested 2026-11-08 on Ubuntu 24.04, libfido2 1.14.0; evidence 1 and 2).**

```sh
{ echo "credential challenge" | openssl sha256 -binary | base64; echo example.test; echo alice; head -c 32 /dev/urandom | base64; } > cred_param
sudo fido2-cred -M -i cred_param /dev/hidraw0 es256 | sudo fido2-cred -V -o cred es256     # exit 0 0
sudo head -1 cred > cred_id; sudo tail -n +2 cred > pubkey
{ echo "assertion challenge" | openssl sha256 -binary | base64; echo example.test; sudo head -1 cred; } > assert_param
sudo fido2-assert -G -i assert_param /dev/hidraw0 | sudo fido2-assert -V pubkey es256      # exit 0 0
# the same credential id for another relying party (other.test instead of example.test):
#   fido2-assert: fido_dev_get_assert: FIDO_ERR_NO_CREDENTIALS
```

**Browsers (tested 2026-11-07 and 08, evidence 5).** The page below, served with `python3 -m http.server 8000` from its directory and opened at `http://localhost:8000/` in each browser (add `?uv=required` or `?rk=required` for the two option rows), clicking *create* and then *get*. Chromium 156.0.8078.4 and Firefox 157.0 were Playwright builds started headed under `xvfb-run`. The Playwright script that clicked the buttons was not kept; the page and the device log (`lhctap.log`, one line per CTAP request) show every result.

```html
<!doctype html><meta charset=utf-8><title>Linux Hello spike</title>
<button id=create>create</button> <button id=get>get</button> <pre id=out>idle</pre>
<script>
const b64 = b => btoa(String.fromCharCode(...new Uint8Array(b)));
let cred = null;
create.onclick = async () => { try {
  out.textContent = 'CREATE pending';
  cred = await navigator.credentials.create({publicKey: {
    challenge: crypto.getRandomValues(new Uint8Array(32)), rp: {name: 'Spike', id: 'localhost'},
    user: {id: new Uint8Array([1,2,3,4]), name: 'alice', displayName: 'Alice'},
    pubKeyCredParams: [{type: 'public-key', alg: -7}],
    authenticatorSelection: {userVerification: (new URLSearchParams(location.search).get("uv") || "discouraged"), residentKey: (new URLSearchParams(location.search).get("rk") || "discouraged")},
    attestation: 'none', timeout: 60000}});
  out.textContent = 'CREATE OK rawId=' + cred.rawId.byteLength + ' bytes, attachment=' + cred.authenticatorAttachment +
    ', transports=' + JSON.stringify(cred.response.getTransports ? cred.response.getTransports() : null);
} catch (e) { out.textContent = 'CREATE ERR ' + e.name + ': ' + e.message; } };
get.onclick = async () => { try {
  out.textContent = 'GET pending';
  const a = await navigator.credentials.get({publicKey: {
    challenge: crypto.getRandomValues(new Uint8Array(32)), rpId: 'localhost', userVerification: 'discouraged',
    allowCredentials: [{type: 'public-key', id: cred.rawId}], timeout: 60000}});
  out.textContent = 'GET OK signature=' + a.response.signature.byteLength + ' bytes, authData=' + a.response.authenticatorData.byteLength + ' bytes';
} catch (e) { out.textContent = 'GET ERR ' + e.name + ': ' + e.message; } };
</script>
```

**Wrong PIN and PIN change (tested 2026-11-07, evidence 3 and 4).** The script `t2.sh`, run in the guest after one credential had been made (`cred.out` is the output of `fido2-cred -M`, kept in the guest only):

```sh
cd ~
assert() { CDH2=$(head -c 32 /dev/urandom | base64 -w0); CRED=$(sudo sed -n 5p cred.out); ( echo "$CDH2"; echo "example.test"; echo "$CRED" ) | sudo fido2-assert -G /dev/hidraw0 2>&1 | head -1 | cut -c1-120; }
stopd() { [ -f lh.pid ] && sudo kill "$(cat lh.pid)" 2>/dev/null; sudo pkill -x python3; sleep 2; }
startd() { sudo -E LH_PIN=$1 nohup python3 lhctap.py > lhctap.log 2>&1 & echo $! > lh.pid; sleep 5; }
echo "== A. WRONG PIN, old credential"
stopd; startd wrong-pin; assert; echo "TPM refused lines: $(grep -c 'TPM refused' lhctap.log)"
echo "DA lockout counter:"; sudo tpm2_getcap properties-variable 2>/dev/null | grep -A1 TPM2_PT_LOCKOUT_COUNTER | tr -d "\n"; echo
echo "== B. change the root key PIN in place (tpm2_changeauth), credential kept"
stopd
cd /var/lib/lhctap && sudo tpm2_createprimary -C o -G ecc -c prim.ctx >/dev/null && sudo tpm2_load -C prim.ctx -u r.pub -r r.priv -c r.ctx >/dev/null && sudo tpm2_changeauth -c r.ctx -C prim.ctx -p 123456 -r r.priv.new new-pin-654321; echo "changeauth exit=$?"
sudo cp r.priv r.priv.old; sudo mv r.priv.new r.priv; cd ~
startd new-pin-654321; echo "new PIN, old credential (blank line = signature returned):"; assert; echo "signed lines: $(grep -c 'signed in the TPM' lhctap.log)"
echo "== C. old PIN against the new blob"
stopd; startd 123456; assert; echo "TPM refused lines: $(grep -c 'TPM refused' lhctap.log)"
echo "== D. old blob + old PIN (no revocation)"
stopd; sudo cp /var/lib/lhctap/r.priv /var/lib/lhctap/r.priv.new; sudo cp /var/lib/lhctap/r.priv.old /var/lib/lhctap/r.priv
startd 123456; assert; echo "signed lines: $(grep -c 'signed in the TPM' lhctap.log)"
```

## Appendix: prototype (`lhctap.py`)

Run as root in the test VM: `sudo -E LH_PIN=123456 python3 lhctap.py`. Not production code.

```python
#!/usr/bin/env python3
"""Spike #94 prototype: a virtual CTAP2 authenticator on uhid whose credential keys live in a TPM.

Not production code. It answers one question: does a uhid FIDO device whose keys are TPM keys under a
PIN-protected root key work with stock clients? Run as root in the test VM:

    LH_PIN=123456 sudo -E python3 lhctap.py

Credential model: every credential is a fresh ECC P-256 signing key, a child of a per-user root key R
(a non-primary storage key protected by the PIN, see spike 0011). The credential ID is the key's TPM
blobs, so nothing is stored on disk per credential (non-resident credentials only).
No user-presence prompt: every request is approved (the spike measures the transport, not the prompt).
"""
import hashlib, os, select, struct, subprocess, sys, tempfile, time

import cbor2
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature
from cryptography.hazmat.primitives.serialization import load_pem_public_key

PIN = os.environ.get("LH_PIN", "123456")
STATE = os.environ.get("LH_STATE", "/var/lib/lhctap")
UHID_EVENT = 4380

# linux/uhid.h
UHID_DESTROY, UHID_START, UHID_STOP, UHID_OPEN, UHID_CLOSE, UHID_OUTPUT = 1, 2, 3, 4, 5, 6
UHID_CREATE2, UHID_INPUT2 = 11, 12

# FIDO HID report descriptor: usage page 0xF1D0, usage 1, one 64-byte input and one 64-byte output report.
RDESC = bytes([0x06, 0xD0, 0xF1, 0x09, 0x01, 0xA1, 0x01,
               0x09, 0x20, 0x15, 0x00, 0x26, 0xFF, 0x00, 0x75, 0x08, 0x95, 0x40, 0x81, 0x02,
               0x09, 0x21, 0x15, 0x00, 0x26, 0xFF, 0x00, 0x75, 0x08, 0x95, 0x40, 0x91, 0x02,
               0xC0])

CTAPHID_PING, CTAPHID_MSG, CTAPHID_INIT, CTAPHID_WINK, CTAPHID_CBOR, CTAPHID_ERROR = 0x01, 0x03, 0x06, 0x08, 0x10, 0x3F
BROADCAST = b"\xff\xff\xff\xff"


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, file=sys.stderr, flush=True)


# ---- TPM (tpm2-tools; the spike measures feasibility, a Rust daemon would use tss-esapi) -------------
class Tpm:
    def __init__(self):
        os.makedirs(STATE, exist_ok=True)
        self.dir = STATE
        self.prim = f"{STATE}/prim.ctx"
        self.root = f"{STATE}/r.ctx"
        self.run("tpm2_createprimary", "-C", "o", "-G", "ecc", "-c", self.prim)
        if not os.path.exists(f"{STATE}/r.pub"):
            self.run("tpm2_create", "-C", self.prim, "-G", "ecc256:null:aes128cfb",
                     "-a", "restricted|decrypt|fixedtpm|fixedparent|sensitivedataorigin|userwithauth",
                     "-p", PIN, "-u", f"{STATE}/r.pub", "-r", f"{STATE}/r.priv")
            log("created the root key R under the primary (PIN set)")
        self.run("tpm2_load", "-C", self.prim, "-u", f"{STATE}/r.pub", "-r", f"{STATE}/r.priv", "-c", self.root)

    def run(self, *cmd):
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode != 0:
            raise RuntimeError(f"{cmd[0]} failed: {p.stderr.strip()[:300]}")
        return p.stdout

    def new_credential(self):
        with tempfile.TemporaryDirectory() as d:
            self.run("tpm2_create", "-C", self.root, "-P", PIN, "-G", "ecc256:ecdsa-sha256",
                     "-a", "sign|fixedtpm|fixedparent|sensitivedataorigin|userwithauth",
                     "-u", f"{d}/c.pub", "-r", f"{d}/c.priv")
            self.run("tpm2_load", "-C", self.root, "-P", PIN, "-u", f"{d}/c.pub", "-r", f"{d}/c.priv", "-c", f"{d}/c.ctx")
            self.run("tpm2_readpublic", "-c", f"{d}/c.ctx", "-f", "pem", "-o", f"{d}/c.pem")
            nums = load_pem_public_key(open(f"{d}/c.pem", "rb").read()).public_numbers()
            return open(f"{d}/c.pub", "rb").read(), open(f"{d}/c.priv", "rb").read(), nums.x, nums.y

    def sign(self, pub, priv, message):
        with tempfile.TemporaryDirectory() as d:
            open(f"{d}/c.pub", "wb").write(pub)
            open(f"{d}/c.priv", "wb").write(priv)
            open(f"{d}/m", "wb").write(message)
            self.run("tpm2_load", "-C", self.root, "-P", PIN, "-u", f"{d}/c.pub", "-r", f"{d}/c.priv", "-c", f"{d}/c.ctx")
            self.run("tpm2_sign", "-c", f"{d}/c.ctx", "-g", "sha256", "-s", "ecdsa", "-f", "plain", "-o", f"{d}/sig", f"{d}/m")
            raw = open(f"{d}/sig", "rb").read()
        if len(raw) == 64:  # r||s
            return encode_dss_signature(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big"))
        return raw  # already DER


# ---- CTAP2 ---------------------------------------------------------------------------------------
class Ctap:
    def __init__(self, tpm):
        self.tpm = tpm
        self.counter_file = f"{STATE}/counter"

    def counter(self):
        n = int(open(self.counter_file).read()) + 1 if os.path.exists(self.counter_file) else 1
        open(self.counter_file, "w").write(str(n))
        return n

    def handle(self, req):
        cmd, body = req[0], (cbor2.loads(req[1:]) if len(req) > 1 else {})
        if cmd == 0x04:
            return b"\x00" + cbor2.dumps({1: ["FIDO_2_0"], 3: bytes(16), 4: {"rk": False, "up": True, "plat": False}, 5: 1200}, canonical=True)
        if cmd == 0x01:
            return self.make_credential(body)
        if cmd == 0x02:
            return self.get_assertion(body)
        log("unsupported CTAP command", hex(cmd))
        return b"\x01"

    def make_credential(self, b):
        rp_id = b[2]["id"]
        opts = b.get(7, {})
        if opts.get("rk") or opts.get("uv"):
            log("refused options", opts)
            return b"\x2b"  # CTAP2_ERR_UNSUPPORTED_OPTION
        if not any(p.get("alg") == -7 for p in b[4]):
            return b"\x26"  # CTAP2_ERR_UNSUPPORTED_ALGORITHM
        rp_hash = hashlib.sha256(rp_id.encode()).digest()
        pub, priv, x, y = self.tpm.new_credential()
        cred_id = b"LH1" + rp_hash[:4] + struct.pack(">H", len(pub)) + pub + struct.pack(">H", len(priv)) + priv
        cose = cbor2.dumps({1: 2, 3: -7, -1: 1, -2: x.to_bytes(32, "big"), -3: y.to_bytes(32, "big")}, canonical=True)
        auth = rp_hash + bytes([0x41]) + struct.pack(">I", self.counter()) + bytes(16) + struct.pack(">H", len(cred_id)) + cred_id + cose
        log(f"MakeCredential rp={rp_id} credential id {len(cred_id)} bytes")
        # self-attestation ("packed", alg -7): the new credential key signs authData || clientDataHash
        sig = self.tpm.sign(pub, priv, auth + b[1])
        return b"\x00" + cbor2.dumps({1: "packed", 2: auth, 3: {"alg": -7, "sig": sig}}, canonical=True)

    def get_assertion(self, b):
        rp_id, cdh = b[1], b[2]
        rp_hash = hashlib.sha256(rp_id.encode()).digest()
        for c in b.get(3, []):
            cid = c["id"]
            if cid[:3] != b"LH1" or cid[3:7] != rp_hash[:4]:
                continue
            n = struct.unpack(">H", cid[7:9])[0]
            pub = cid[9:9 + n]
            m = struct.unpack(">H", cid[9 + n:11 + n])[0]
            priv = cid[11 + n:11 + n + m]
            auth = rp_hash + bytes([0x01]) + struct.pack(">I", self.counter())
            try:
                sig = self.tpm.sign(pub, priv, auth + cdh)
            except RuntimeError as e:
                log("TPM refused", e)
                continue
            log(f"GetAssertion rp={rp_id} signed in the TPM")
            return b"\x00" + cbor2.dumps({1: {"id": cid, "type": "public-key"}, 2: auth, 3: sig}, canonical=True)
        log("GetAssertion: no usable credential for", rp_id)
        return b"\x2e"  # CTAP2_ERR_NO_CREDENTIALS


# ---- CTAPHID over uhid -----------------------------------------------------------------------------
class Device:
    def __init__(self, ctap):
        self.ctap = ctap
        self.fd = os.open("/dev/uhid", os.O_RDWR)
        self.next_cid = 1
        self.pending = {}
        create = struct.pack("<I128s64s64sHHIIII4096s", UHID_CREATE2, b"Linux Hello spike", b"", b"",
                             len(RDESC), 3, 0x1209, 0xF1D0, 1, 0, RDESC.ljust(4096, b"\0"))
        os.write(self.fd, create)
        log("uhid device created")

    def send(self, cid, cmd, data):
        pkt = (cid + bytes([0x80 | cmd]) + struct.pack(">H", len(data)) + data[:57]).ljust(64, b"\0")
        self.input(pkt)
        data, seq = data[57:], 0
        while data:
            self.input((cid + bytes([seq]) + data[:59]).ljust(64, b"\0"))
            data, seq = data[59:], seq + 1

    def input(self, pkt):
        os.write(self.fd, struct.pack("<IH4096s", UHID_INPUT2, 64, pkt.ljust(4096, b"\0")))

    def packet(self, pkt):
        cid = pkt[:4]
        if pkt[4] & 0x80:
            cmd, n = pkt[4] & 0x7F, (pkt[5] << 8) | pkt[6]
            self.pending[cid] = [cmd, n, bytearray(pkt[7:7 + n])]
        elif cid in self.pending:
            self.pending[cid][2] += pkt[5:64]
        else:
            return
        cmd, n, data = self.pending[cid]
        if len(data) < n:
            return
        del self.pending[cid]
        self.message(cid, cmd, bytes(data[:n]))

    def message(self, cid, cmd, data):
        if cmd == CTAPHID_INIT:
            new = BROADCAST if False else struct.pack(">I", self.next_cid)
            self.next_cid += 1
            log("CTAPHID_INIT, new channel", new.hex())
            self.send(cid, CTAPHID_INIT, data[:8] + new + bytes([2, 1, 0, 0, 0x04 | 0x08]))
        elif cmd == CTAPHID_PING:
            self.send(cid, CTAPHID_PING, data)
        elif cmd == CTAPHID_WINK:
            self.send(cid, CTAPHID_WINK, b"")
        elif cmd == CTAPHID_CBOR:
            try:
                resp = self.ctap.handle(data)
            except Exception as e:  # keep the device alive; report a generic CTAP error
                log("CBOR error", repr(e))
                resp = b"\x7f"
            self.send(cid, CTAPHID_CBOR, resp)
        else:
            self.send(cid, CTAPHID_ERROR, b"\x01")

    def loop(self):
        while True:
            select.select([self.fd], [], [])
            ev = os.read(self.fd, UHID_EVENT)
            kind = struct.unpack_from("<I", ev)[0]
            if kind == UHID_OUTPUT:
                size = struct.unpack_from("<H", ev, 4 + 4096)[0]
                data = ev[4:4 + size]
                if size == 65 and data[0] == 0:
                    data = data[1:]
                self.packet(bytes(data[:64]))
            elif kind in (UHID_START, UHID_OPEN, UHID_CLOSE, UHID_STOP):
                log("uhid event", {2: "START", 3: "STOP", 4: "OPEN", 5: "CLOSE"}[kind])


if __name__ == "__main__":
    tpm = Tpm()
    Device(Ctap(tpm)).loop()
```
