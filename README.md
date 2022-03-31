# AdGuard Certificate

Based on [Move Certificates](https://github.com/Magisk-Modules-Repo/movecert).

This Magisk module supplements [AdGuard for Android](agandroid) and allows installing
AdGuard's CA certificate to the system store.

## Why you could need it?

AdGuard provides a feature called [HTTPS filtering](httpsfiltering). It allows
filtering of encrypted HTTPS traffic on your Android device. This feature requires
installing the AdGuard's CA certificate to the list of trusted certificates.

By default on a non-rooted device only a limited subset of apps (mostly, browsers)
trust the CA certificate installed to the "User store". The only option to allow
filtering of all apps is to install the certificate to the "System store".
Unfortunately, this is only possible on a rooted device.

[agandroid]: https://adguard.com/adguard-android/overview.html
[httpsfiltering]: https://kb.adguard.com/en/general/https-filtering

## Usage

1. Enable HTTPS filtering and save/install AdGuard's certificate to the user store.
2. Go to Magisk->Settings and enable Zygisk.
3. Download the zip file from [latest release](latestrelease).
4. Go to Magisk->Modules->Install from storage, and select the downloaded zip file.
5. Reboot.

To update the module if a new version comes out, repeat steps 3-5.

[latestrelease]: https://github.com/AdguardTeam/adguardcert/releases/latest/

## Chrome and Chromium-based browsers

Chrome recently started requiring CT logs for CA certs found in the "System store".
This module copies AdGuard's CA certificate from the "User store" to the "System store".
It also contains a Zygisk module that reverts any modifications done by Magisk for
Chrome's processes. This way Chrome only finds AdGuard's certificate in the user store
and doesn't complain about the missing CT log, while other apps continue to use the
same certificate from the system store.

## Building

Update git modules:

```shell
git submodule init && git submodule update
```

You'll need an Android SDK with NDK installed (tested with NDK 22 and 23). Run:

```shell
ANDROID_HOME=<path-to-android-sdk> ./dist.sh
```

## Advanced

If you prefer to manage your Zygisk denylist yourself, simply remove the Zygisk part of the module:

```shell
zip adguardcert-v1.0.zip -d "zygisk/*"
```
