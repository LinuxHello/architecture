---
type: adr
subject: The 1.0 browser path is an own web extension and native-messaging host in front of the broker, until browsers call the credentials portal
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [webauthn, browser-extension, native-messaging, origin, snap, flatpak]
tags: [adr, upstream]
sources: ["../spikes/0006-browser-webauthn-portal.md", "../spikes/0033-own-extension-origin-and-confined-native-messaging.md", "0005-provider-path.md", "../arc42/04-solution-strategy.md", "../arc42/08-crosscutting-concepts.md", "https://github.com/LinuxHello/linux-hello/issues/33"]
date: 2026-11-07
---

# ADR-0013: Browser path for 1.0

## Status

Proposed, 2026-11-07. Superseded by [ADR-0017](0017-browser-path.md) (proposed, 2026-11-08), which takes the browser path from ADR-0005 option B.

## Context

No stock browser sends WebAuthn requests to the credentials portal or to credentialsd ([spike 0006](../spikes/0006-browser-webauthn-portal.md)). The Firefox source has no Linux platform authenticator; Chromium creates platform discoveries only for macOS and ChromeOS. So 1.0 needs a browser path that does not depend on the browser, and design rule 4 ("one path for all clients", [section 4](../arc42/04-solution-strategy.md#design-rules)) does not hold for browsers until they call the portal.

[ADR-0005](0005-provider-path.md) (option D) gives Linux Hello its own broker in front of the TPM provider and the KeePassXC bridge. A browser path has to reach that broker without breaking the "Caller impersonation" threat in [section 8](../arc42/08-crosscutting-concepts.md#threats-to-design-against): "never trust a caller-supplied origin from an unprivileged client".

[Spike 0033](../spikes/0033-own-extension-origin-and-confined-native-messaging.md) (source read; the hands-on run is open) found:

- An extension can get the origin from the browser: `runtime.MessageSender.origin`, in Chrome 80+ and Firefox. The browser starts the native-messaging host with the extension ID as an argument and admits only the extensions the host manifest lists (`allowed_extensions` in Firefox, `allowed_origins` in Chrome).
- The upstream WebExtensions portal for confined browsers was never merged. Its replacement, `xdg-native-messaging-proxy` (0.1.0), calls itself potentially insecure and has no user prompt. Ubuntu ships the old portal as a patch. Firefox supports both, behind prefs that are off by default upstream, so Snap and Flatpak packages must turn them on.
- It is open who passes the extension-ID argument when the proxy starts the host.

The options:

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. KeePassXC-Browser** as the browser path | Released; works on any site; no work for us | Software keys unlocked by the KeePassXC database; no TPM custody, so the routing policy (design rule 3) cannot send a relying party to the TPM; bypasses the broker and the unlock gate |
| **B. The credentialsd web extension** | Exists; same mechanism as C | Two demo sites only (spike 0006, evidence 4); takes the origin from the page (evidence 5), which breaks the "Caller impersonation" rule; talks to credentialsd, not to the ADR-0005 broker; upstream calls it a testing aid |
| **C. Own web extension and native-messaging host**, in front of the broker | TPM and KeePassXC custody through the routing policy; origin supplied by the browser (spike 0033); any site; retires cleanly when browsers call the portal | We own the extension, the host and their store listings; we take over WebAuthn checks the browser normally does; confined browsers depend on the distribution (proxy or Ubuntu portal patch) |
| **D. No browser path in 1.0** | No extra work | Browsers are the main passkey client; 1.0 would cover only native and Electron apps |

## Decision

**Option C.** Linux Hello ships its own web extension for Firefox and Chromium and a native-messaging host that talks to the ADR-0005 broker. It is the browser path for 1.0 and stays until stock Firefox and Chromium call the credentials portal.

The origin chain is fixed as follows:

1. The page-world shim forwards only the WebAuthn options. It never sends an origin.
2. The extension's background script takes the origin from `sender.origin`, rejects opaque origins, and checks that the frame and top-level origin match the request. It does what the browser would otherwise do: the RP ID must be the origin's host or a registrable-domain suffix of it (Public Suffix List); secure contexts only; iframe permissions policy (`publickey-credentials-create` and `-get`); user activation where the WebAuthn specification requires it; and it builds `clientDataJSON`.
3. The host manifest lists only our extension. The host also checks the extension ID it receives as an argument.
4. The broker accepts requests only from the host. The user-presence prompt is rendered by the broker, outside the browser, and names the relying party.

Supported browsers for 1.0:

| Browser | Status |
| :-- | :-- |
| Firefox and Chromium installed unpacked (distribution package or vendor `.deb`/`.rpm`) | Supported |
| Firefox as Snap or Flatpak | Supported only where the distribution provides `xdg-native-messaging-proxy` or Ubuntu's WebExtensions portal and the package turns on the pref. Documented, tested per release, not promised |
| Chromium as Snap or Flatpak | Not supported until tested |

Retire this path, in a new ADR that supersedes this one, when stock Firefox and Chromium release builds call the credentials portal and that portal ships in a release. Until then design rule 4 carries this ADR as its exception.

The native-messaging host name is a one-way door (invariant 7). It is chosen with the host's issue, following [ADR-0012](0012-dbus-names.md) as far as the native-messaging naming rules allow (lower case, dots and underscores).

## Consequences

**Easier:** 1.0 covers browsers with TPM custody and the routing policy, not only native and Electron apps; the origin comes from the browser, which meets the "Caller impersonation" rule; the extension and host are thin and go away when browsers call the portal.

**Harder:**

- Linux Hello owns two new containers (extension and host), two store listings (AMO, Chrome Web Store) and their signing.
- The extension must reimplement browser-side WebAuthn checks; each one it misses is a security gap. Each check needs a security property in `docs/security/` and a test named after it before code.
- Site compatibility: responses must behave like `PublicKeyCredential` (`instanceof`, `toJSON()`, `getTransports()`), and `isUserVerifyingPlatformAuthenticatorAvailable()`, `getClientCapabilities()` and conditional mediation need shims.
- It conflicts with KeePassXC-Browser's passkey support if both are enabled, since both replace `navigator.credentials`. Users who keep portable keys in KeePassXC reach them through the broker and the KeePassXC bridge instead; the install docs must say to turn off KeePassXC-Browser's passkey option.
- Confined browsers are outside our control. Under the proxy, our own checks (host extension-ID check, broker prompt) may be the only guard; the open point in spike 0033 (evidence 6) must be settled before the Snap row is tested.

Follow-up, before this ADR is accepted:

- `workspace.dsl` and [section 5](../arc42/05-building-block-view.md): add the extension and host containers and the `browsers -> extension -> host -> broker` relations.
- [Section 4](../arc42/04-solution-strategy.md#design-rules), design rule 4, and [section 8](../arc42/08-crosscutting-concepts.md#threats-to-design-against): name this ADR as the browser exception and the origin chain as the "Caller impersonation" mitigation for browsers.
- The hands-on part of spike 0033 confirms the unconfined rows of the support table.
