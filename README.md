# AdGuard Certificate

Based on [Move Certificates](https://github.com/Magisk-Modules-Repo/movecert).

This module supplements [AdGuard for Android][agandroid] and allows installing
AdGuard's Personal CA certificate to the Android system trust store on rooted
devices. It is compatible with Magisk-style modules and is optimized for modern
KernelSU/APatch setups with a metamodule such as Hybrid Mount.

**Attention**
[Current version](https://github.com/AdguardTeam/adguardcert/releases/latest)
of this module is designed for Adguard for Android 4.2 and newer.

If you're using AdGuard for Android v4.1 or older, please use the earlier version of
this magisk module: https://github.com/AdguardTeam/adguardcert/releases/tag/v1.2.

## Explanation

Chrome (and subsequently many other Chromium-based browsers)
has recently started requiring Certificate Transparency logs
for CA certs found in the **system certificate store**.

If your device is rooted, and you want AdGuard's certificate to be installed
in the **system store**, then AdGuard will generate two CA certificates and ask you
to install both of them in the **user store**. This module moves one of them to the
**system store**. The certificate that is left in the **user store** is cross-signed
with the one that goes into the **system store**. This allows apps that don't trust
user certificates to still accept AdGuard's certificate, while apps that do trust
user certificates (like Chrome or other browsers) will construct a shorter validation
path to the certificate stored in the **user store**. And since it is stored in the
**user store**, they won't require CT logs.

On Android 14 and newer, the main system CA directory used by Conscrypt is
`/apex/com.android.conscrypt/cacerts`. The module prepares a complete mirror of
the stock Conscrypt trust store, adds only AdGuard's Personal CA, and also handles
versioned Conscrypt APEX paths such as `/apex/com.android.conscrypt@*/cacerts`
when they are present. The AdGuard Personal Intermediate CA remains in the user
store.

## Why would I want AdGuard's certificate in the system store?

AdGuard for Android provides a feature called [HTTPS filtering][httpsfiltering]. It allows
filtering of encrypted HTTPS traffic on your Android device. This feature requires
adding the AdGuard's CA certificate to the list of trusted certificates.

By default, on a non-rooted device only a limited subset of apps (mostly, browsers)
trust the CA certificates installed to the **user store**. The only option to allow
filtering of all other apps' traffic is to install the certificate to the **system store**.
Unfortunately, this is only possible on rooted devices.

[agandroid]: https://adguard.com/adguard-android/overview.html
[httpsfiltering]: https://kb.adguard.com/general/https-filtering

## Usage

1. Enable HTTPS filtering in AdGuard for Android and save AdGuard's certificate(s) to the User store
2. Download the `.zip` file from the [latest release][latestrelease].
3. Install the module from your root manager.
4. Reboot.

If a new version comes out, repeat steps 2-4 to update the module.

The module does its work during the system boot. If your AdGuard certificate(s) change,
you'll have to reboot the device for the new certificate to be copied to the system store.

## KernelSU and APatch

KernelSU and APatch require a metamodule for module-provided system file mounts.
Hybrid Mount is the preferred setup for this module. The module registers an
`adguardcert` Hybrid Mount rule for the system and Conscrypt certificate-store
paths when the Hybrid Mount API is available, and also ships the `magic` marker
used by Hybrid Mount Nano. When Hybrid Mount is active, the module stages the
Conscrypt APEX trust-store mirror inside its module tree so the metamodule can
expose it before apps inherit their mount namespaces.

If a KernelSU profile unmounts modules for a target app, that app may not see the
module-provided certificate store. Apps that need AdGuard HTTPS filtering must use
a profile where this module remains mounted.

The module does not rewrite KernelSU profile configuration automatically. Run
`/data/adb/modules/adguardcert/action.sh doctor <package>` to check whether a
specific app process can actually see the staged certificate store.

## Android 17

Android 17 enables Certificate Transparency by default for apps targeting API 37.
Moving AdGuard's Personal CA to the system trust store is still required for apps
that do not trust user CAs, but it cannot override app-level Certificate
Transparency policy, certificate pinning, or custom trust managers.

The doctor command reports `ct_relevant=true` for apps targeting API 37 or newer.
That is a warning that CT can be involved, not proof that CT caused a connection
failure.

## Configuration

Advanced users can create `/data/adb/adguardcert/config.sh` to override detection:

```shell
PERSONAL_HASHES="0f4ed297 14944648"
INTERMEDIATE_HASHES="47ec1af8"
MIN_CERT_COUNT=10
RUNTIME_CHILD_NAMESPACE_MOUNTS=1
```

The default policy is intentionally narrow: copy AdGuard's Personal CA, keep the
AdGuard Personal Intermediate CA in the user store, and leave unrelated user
certificates untouched.

<details>
    <summary>Illustrated instruction</summary>

![Open Magisk modules](https://user-images.githubusercontent.com/5947035/161061277-1ada3a87-d0cb-44c0-9edd-77b00669759c.png)

![Install from storage](https://user-images.githubusercontent.com/5947035/161061283-8e3d6ed2-ca36-4825-bca4-fbb9f9185f68.png)

![Select AdGuard certificate module](https://user-images.githubusercontent.com/5947035/161061285-4ea302ad-99ec-4619-be05-3b83f64b9e4f.png)

![Reboot the device](https://user-images.githubusercontent.com/5947035/161061291-54ad008f-4c76-4ee3-975d-307fd0fe7220.png)

</details>

Please note that in order for **Bromite** browser to work properly, you need to set the "Allow user certificates" flag in `chrome://flags` to "Enabled".

<details>
    <summary>Bromite setup</summary>
    
![Allow user certificates flag](https://user-images.githubusercontent.com/47204/161606690-0e44211a-abd6-4e89-91b0-f012e68294df.png)

</details>

[latestrelease]: https://github.com/larsmartens/adguardcert/releases/latest/

## Building
```shell
./dist.sh
```

How to release a new version:
1. Push a new tag with a name like `v*`.
2. A new release will be automatically created.
