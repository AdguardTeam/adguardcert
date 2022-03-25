# Copy Certificates

Based on [Move Certificates](https://github.com/Magisk-Modules-Repo/movecert).

Chrome recently started requiring CT logs for CA certs found in the system store.
This module copies AdGuard's CA certificate from the user store to the system store.
It also contains a Zygisk module that "hides" any modifications done by Magisk from
Chrome's processes. This way Chrome only finds AdGuard's certificate in the user store
and doesn't complain about the missing CT log, while other apps continue to use the
same certificate from the system store.

# Usage
1. Enable HTTPS filtering and save/install AdGuard's certificate to the user store.
2. Enable Magisk->Settings->Zygisk.
3. Download the zip file from releases.
4. Go to Magisk->Modules->Install from storage and select the downloaded zip file.
5. Reboot.

# Building

Update git modules:
```shell
git submodule init && git submodule update
```

You'll need an Android SDK with NDK version 23.1.7779620. Run:

```shell
ANDROID_SDK=<path-to-android-sdk> ./dist.sh
```

If you prefer to manage your Zygisk denylist yourself, simply remove the Zygisk part of the module:
```shell
zip adguardcert-v1.0.zip -d "zygisk/*"
```
