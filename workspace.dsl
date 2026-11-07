/*
 * Linux Hello — C4 workspace (System Context, Container, Component)
 * Source notes: docs/architecture/ (Arc42 sections, README.md)
 * Status: draft, UNTESTED — validate with the Structurizr CLI before use.
 * Date: 2026-11-08 (ADR-0005 option B; ADR-0014 to 0017; spikes 0008-0012 and 0014)
 */
workspace "Linux Hello" "Biometric- and PIN-gated passkeys and secrets for the Linux desktop" {

    model {
        user = person "Desktop user" "Signs in to the session, websites and apps; enrols methods"
        admin = person "Administrator" "Authorises a trust-chain reset"

        linuxHello = softwareSystem "Linux Hello" "PIN-rooted, biometric-unlocked credential layer integrating upstream Linux components" {

            agent = container "Linux Hello Agent" "Unlock state, auth state, routing policy, PIN, enrolment and reset orchestration" "Rust daemon, systemd system service, D-Bus on the system bus (ADR-0014)" {
                dbusApi = component "D-Bus API" "io.github.LinuxHello.Agent1 on the system bus; verifies peer credentials of every caller, keeps state per uid and sends it by method reply or unicast signal, never a broadcast that names a user or a method (ADR-0014)" "zbus"
                unlockState = component "Unlock State Manager" "Session unlock, expiry and re-prompt rules; state proven by TPM policy sessions, not flags" "Rust"
                authState = component "Auth State Publisher" "Signals MethodsAvailable, ActiveMethod, State, Result per prompt (UX1-UX4)" "zbus signals"
                policyEngine = component "Routing Policy Engine" "Merges default, user and admin layers; answers allowed methods per context, provider and prompt level per relying party, PIN rules; fails closed on unparseable policy" "Rust"
                pinManager = component "PIN Manager" "Change PIN in place, PIN rules, lockout status (UX7b)" "Rust"
                enrolment = component "Enrolment Orchestrator" "First-run PIN, root key creation, second-credential prompts (UX8)" "Rust"
                resetCoord = component "Reset Coordinator" "Destructive reset per ADR-0003 (LH-1)" "Rust"
                auditLog = component "Audit Logger" "Structured journald events for every unlock, sign, PIN change and reset" "Rust"
            }

            pamModule = container "pam_linuxhello" "Parallel face, fingerprint and PIN authentication" "Rust cdylib, Linux-PAM" {
                pamEntry = component "PAM Entry Points" "pam_sm_authenticate and pam_sm_open_session" "Rust FFI"
                methodOrch = component "Method Orchestrator" "Runs face, fingerprint and PIN in parallel; first success wins; cancels the rest (UX3)" "Rust, async"
                pinVerifier = component "PIN Verifier" "Satisfies TPM2 auth on the root key; TPM anti-hammering applies" "Rust"
                faceClient = component "Face Client" "Requests a face match from Howdy" "Rust"
                fingerClient = component "Fingerprint Client" "Requests a verify from fprintd" "zbus"
                agentNotifier = component "Agent Notifier" "Reports method state and session unlock to the Agent" "zbus"
            }

            tpmProvider = container "TPM Credential Provider" "Device-bound passkeys under the per-user TPM root key" "Rust daemon" {
                tpmProviderApi = component "Provider Interface" "Credential operations the Virtual CTAP Authenticator calls; knows nothing about uhid, so another front end can replace it (ADR-0005)" "zbus"
                credStore = component "Credential Index" "Maps relying party and credential ID to TPM key handles; no private material" "Rust"
                tpmKeys = component "TPM Key Service" "Root key as a non-primary child of a storage primary, PIN change in place (new blob, old blob deleted), child keys, policy sessions, signing (spike 0011)" "Rust"
                tpmFfi = component "TPM FFI" "The only crate allowed unsafe code" "tss-esapi"
            }

            kpxcBridge = container "KeePassXC Provider Bridge" "Portable passkeys from KeePassXC" "Rust daemon" {
                kpxcProviderApi = component "Provider Interface" "Credential operations the Virtual CTAP Authenticator calls (ADR-0005)" "zbus"
                kpxcClient = component "KeePassXC Protocol Client" "Encrypted browser-protocol channel to KeePassXC" "Rust, NaCl box"
            }

            ctapHelper = container "Virtual CTAP Authenticator" "Presents Linux Hello as a FIDO security key to browsers and apps; routes each request to a provider by policy (ADR-0005 option B)" "Rust daemon, uhid (privileged helper)"

            plasma = container "Plasma Integration" "Prompts, greeter and lock-screen integration, enrolment and settings" "Rust/cxx-qt, QML, KCM" {
                authPrompt = component "Auth Prompt QML Component" "Shared method indicator and switcher; renders Agent auth state (UX1-UX5). One QML module in the system QML directory, imported by every host below (spike 0009)" "QML"
                promptUi = component "Prompt UI" "In-session user-presence and provider-choice dialogs, outside the calling app" "QML"
                sddmTheme = component "SDDM Theme" "Own theme package (a Breeze fork) that embeds the shared prompt in SDDM (ADR-0016). The Plasma Login Manager needs an upstream change and is not part of 1.0" "QML"
                kcm = component "Linux Hello Settings Module" "Own settings page next to Users in System Settings (kcm_users has no extension point, spike 0010): methods, policy (UX7a)" "KCM, QML"
                faceEnrol = component "Face Enrolment Module" "Capture, recognition test and delete through Howdy; status text and the test result, no live preview in 1.0 (ADR-0015; UX6a deferred)" "QML, Rust"
                pinSettings = component "PIN Settings" "Change PIN, rules, lockout status, forgot-PIN link (UX7b)" "QML"
                wizard = component "Enrolment Wizard" "First run: PIN, then optional face and fingerprint (UX8)" "QML"
                usersKcmPatch = component "Users Page Entries" "Optional, not planned: Face and PIN entries beside fingerprint need an upstream change to kcm_users in plasma-workspace (spike 0010)" "QML patch"
            }

            cli = container "linuxhello-ctl" "Enrol, change PIN, reset, inspect" "Rust CLI" {
                cliCommands = component "Command Parser" "enrol, pin change, reset, policy show" "clap"
                cliAgentClient = component "Agent Client" "Calls the Agent D-Bus API" "zbus"
            }

            policyStore = container "User Policy" "User layer: ~/.config/linuxhello/policy.toml" "TOML" "Data"
            adminPolicyStore = container "Admin Policy" "Admin layer: /etc/linuxhello/policy.d/*.toml, root-owned; locked keys win" "TOML" "Data"

            secProfiles = container "Security Profiles" "Confinement and detection shipped with Linux Hello" "AppArmor, Tetragon, alert rules" {
                aaProfiles = component "AppArmor Profiles" "One enforce profile per daemon and CLI; units refuse to start unconfined" "AppArmor"
                tetraPolicies = component "Tetragon TracingPolicies" "Optional: TPM access, policy and PAM writes, ptrace, network Sigkill" "Tetragon YAML"
                alertRules = component "Alert Rules" "Alerts on Tetragon events and audit log entries" "LogQL"
            }
        }

        uhid = softwareSystem "Linux uhid and hidraw" "Kernel virtual HID device: /dev/uhid creates the FIDO device, browsers and apps reach it through hidraw" "External"
        keepassxc = softwareSystem "KeePassXC" "Password manager holding portable passkeys (GPL)" "External"
        fprintd = softwareSystem "fprintd" "Fingerprint daemon (GPL)" "External"
        howdy = softwareSystem "Howdy" "IR face recognition (MIT). Match as a subprocess (exit status); enrol and test as a root CLI; no library, D-Bus API, preview or detection results (spike 0008)" "External"
        linuxPam = softwareSystem "Linux-PAM" "Pluggable authentication framework" "External"
        tpm = softwareSystem "TPM 2.0" "Kernel resource manager /dev/tpmrm0" "External"
        camera = softwareSystem "Camera" "UVC camera with RGB and IR as separate V4L2 nodes; Howdy holds the IR stream while it captures; the BRIO streams RGB and IR together only in some start orders (spike 0012)" "External"
        secretService = softwareSystem "Secret Service (KWallet)" "Token and secret storage" "External"
        loginManager = softwareSystem "Plasma login manager" "Graphical login: SDDM, or the Plasma Login Manager from Plasma 6.8" "External"
        lockScreen = softwareSystem "kscreenlocker" "Plasma lock screen; a part of the Plasma shell package from 6.8" "External"
        systemSettings = softwareSystem "KDE System Settings" "Hosts KCMs; Users page with a fixed fingerprint entry" "External"
        browsers = softwareSystem "Browsers" "Firefox, Chromium" "External"
        nativeApps = softwareSystem "Native and Electron apps" "e.g. Claude Desktop" "External"
        relyingParties = softwareSystem "Relying parties" "Websites and identity providers" "External"
        apparmor = softwareSystem "AppArmor" "Kernel LSM, mandatory access control" "External"
        tetragon = softwareSystem "Tetragon" "eBPF runtime security (optional)" "External"
        journald = softwareSystem "systemd-journald" "System log" "External"
        logStack = softwareSystem "Log stack" "e.g. Alloy, Loki, Grafana" "External"
        mgmt = softwareSystem "Device management" "Future: delivers admin policy, as Intune does" "External"

        # People
        user -> loginManager "Signs in"
        user -> lockScreen "Unlocks"
        user -> browsers "Signs in to websites"
        user -> nativeApps "Uses"
        user -> systemSettings "Manages sign-in methods"
        user -> promptUi "Confirms, switches method"
        user -> wizard "Enrols on first run"
        admin -> cliCommands "Authorises reset"

        # External to external (context only)
        browsers -> uhid "WebAuthn requests as CTAP2 to a USB security key" "hidraw"
        nativeApps -> uhid "WebAuthn requests as CTAP2 to a USB security key" "hidraw"
        nativeApps -> secretService "Stores tokens" "Secret Service API"
        browsers -> relyingParties "WebAuthn ceremonies" "HTTPS"
        uhid -> ctapHelper "Delivers CTAP2 reports" "/dev/uhid"
        loginManager -> linuxPam "Authenticates via"
        lockScreen -> linuxPam "Authenticates via the stock kde, kde-face and kde-fingerprint services; text only on 6.8, inside the kde service on 6.6 (ADR-0016)"

        # KDE integration
        loginManager -> sddmTheme "Loads theme" "QML"
        sddmTheme -> authPrompt "Embeds"
        promptUi -> authPrompt "Embeds"
        authPrompt -> dbusApi "Subscribes to auth state, selects method, over the system bus (ADR-0014)" "D-Bus"
        systemSettings -> kcm "Hosts" "KCM"
        systemSettings -> usersKcmPatch "Shows entries on Users page"
        usersKcmPatch -> faceEnrol "Opens"
        usersKcmPatch -> pinSettings "Opens"
        kcm -> faceEnrol "Opens"
        kcm -> pinSettings "Opens"
        kcm -> dbusApi "Reads and writes settings" "D-Bus"
        kcm -> policyStore "Writes user policy" "TOML"
        wizard -> dbusApi "Starts enrolment" "D-Bus"
        wizard -> systemSettings "Hands off fingerprint enrolment to Users page"
        faceEnrol -> howdy "Enrol, test, delete through the howdy CLI in a privileged Agent helper; no preview or detection results (ADR-0015)" "subprocess"
        howdy -> camera "Reads the IR stream while it captures" "V4L2"
        pinSettings -> dbusApi "Change PIN, lockout status" "D-Bus"
        ctapHelper -> promptUi "User-presence and choice prompts" "D-Bus"
        promptUi -> dbusApi "Reads routing decision, authenticates" "D-Bus"

        # PAM module
        linuxPam -> pamEntry "Loads module" "PAM stack"
        pamEntry -> methodOrch "Authenticate"
        methodOrch -> pinVerifier "PIN path"
        methodOrch -> faceClient "Face path"
        methodOrch -> fingerClient "Fingerprint path"
        methodOrch -> agentNotifier "Method state and result"
        pinVerifier -> tpm "TPM2 policy auth" "TCTI device"
        faceClient -> howdy "Match request; result is the exit status" "subprocess"
        fingerClient -> fprintd "Verify" "D-Bus"
        agentNotifier -> dbusApi "Auth state, session unlocked" "D-Bus"

        # Agent
        dbusApi -> unlockState "Unlock queries"
        dbusApi -> authState "State updates"
        dbusApi -> policyEngine "Routing queries"
        dbusApi -> pinManager "PIN requests"
        dbusApi -> enrolment "Enrol requests"
        dbusApi -> resetCoord "Reset requests"
        policyEngine -> policyStore "Reads" "TOML"
        pinManager -> tpmKeys "Change root key auth" "D-Bus"
        enrolment -> tpmKeys "Create root key" "D-Bus"
        resetCoord -> tpmKeys "Destroy root key" "D-Bus"
        resetCoord -> linuxPam "Verifies account password" "PAM conversation"
        unlockState -> auditLog "Events"
        pinManager -> auditLog "Events"
        resetCoord -> auditLog "Events"

        # Providers
        ctapHelper -> tpmProviderApi "Credential operations" "D-Bus"
        ctapHelper -> dbusApi "Checks unlock and routing policy" "D-Bus"
        tpmProviderApi -> dbusApi "Checks unlock and policy" "D-Bus"
        tpmProviderApi -> credStore "Looks up credentials"
        tpmProviderApi -> tpmKeys "Sign assertion"
        tpmKeys -> tpmFfi "ESAPI calls"
        tpmFfi -> tpm "Commands" "/dev/tpmrm0"
        ctapHelper -> kpxcProviderApi "Credential operations" "D-Bus"
        kpxcProviderApi -> dbusApi "Checks unlock and policy" "D-Bus"
        kpxcProviderApi -> kpxcClient "Get or create passkey"
        kpxcClient -> keepassxc "Browser protocol" "Unix socket"

        # Policy
        policyEngine -> adminPolicyStore "Reads; locked keys win" "TOML"
        pinManager -> policyEngine "PIN rules"
        methodOrch -> dbusApi "Allowed methods for context" "D-Bus"
        admin -> adminPolicyStore "Writes admin policy"
        mgmt -> adminPolicyStore "Delivers admin policy (future)"

        # Confinement and monitoring
        aaProfiles -> apparmor "Loaded into (enforce)"
        apparmor -> agent "Confines"
        apparmor -> tpmProvider "Confines"
        apparmor -> kpxcBridge "Confines"
        apparmor -> ctapHelper "Confines"
        apparmor -> cli "Confines"
        tetraPolicies -> tetragon "Loaded into"
        tetragon -> logStack "Security events"
        auditLog -> journald "Audit events"
        journald -> logStack "Shipped by Alloy"
        alertRules -> logStack "Loaded into"

        # CLI
        cliCommands -> cliAgentClient "Invokes"
        cliAgentClient -> dbusApi "Calls" "D-Bus"
    }

    views {
        systemContext linuxHello "Context" {
            include *
            autoLayout lr
        }
        container linuxHello "Containers" {
            include *
            autoLayout lr
        }
        component agent "Agent" {
            include *
            autoLayout lr
        }
        component pamModule "PAM" {
            include *
            autoLayout lr
        }
        component tpmProvider "TPMProvider" {
            include *
            autoLayout lr
        }
        component kpxcBridge "KeePassXCBridge" {
            include *
            autoLayout lr
        }
        component plasma "Plasma" {
            include *
            autoLayout lr
        }
        component cli "CLI" {
            include *
            autoLayout lr
        }
        component secProfiles "SecurityProfiles" {
            include *
            autoLayout lr
        }
        styles {
            element "Person" {
                shape person
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Data" {
                shape cylinder
            }
        }
    }
}
