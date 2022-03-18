# Copy Certificates

Based on [Move Certificates](https://github.com/Magisk-Modules-Repo/movecert). Copies certificates
from the user certificate store to the system store, while also forcing Chrome on the Zygisk
denylist. This way Chrome still sees the custom certificates in the user store, while other apps see
them in the system store. Useful since Chrome started requiring CT logs for all certs in the system
store.

# Building

You'll need Android SDK with NDK v23.1.7779620. Run:

```shell
ANDROID_SDK=<path-to-android-sdk> ./dist.sh
```

If you prefer to manage your Zygisk denylist yourself, simply remove the Zygisk part of the module:
```shell
zip CopyCert-v1.0.zip -d "zygisk/*"
```
