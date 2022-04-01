# AdGuard Certificate

Based on [Move Certificates](https://github.com/Magisk-Modules-Repo/movecert).

This Magisk module supplements [AdGuard for Android][agandroid] and allows installing
AdGuard's CA certificate to the System store on rooted devices.

## Why could you need it?

AdGuard for Android provides a feature called [HTTPS filtering][httpsfiltering]. It allows
filtering of encrypted HTTPS traffic on your Android device. This feature requires
adding the AdGuard's CA certificate to the list of trusted certificates.

By default, on a non-rooted device only a limited subset of apps (mostly, browsers)
trust the CA certificates installed to the **User store**. The only option to allow
filtering of all other apps' traffic is to install the certificate to the **System store**.
Unfortunately, this is only possible on rooted devices.

[agandroid]: https://adguard.com/adguard-android/overview.html
[httpsfiltering]: https://kb.adguard.com/general/https-filtering

## Usage

1. Enable HTTPS filtering in AdGuard for Android and save AdGuard's certificate to the User store.
2. Go to *Magisk -> Settings* and enable **Zygisk**.
3. Download the `.zip` file from the [latest release][latestrelease].
4. Go to *Magisk -> Modules -> Install from storage* and select the downloaded `.zip` file.
5. Reboot.

If a new version comes out, repeat steps 3-5 to update the module.

<details>
    <summary>Illustrated instruction</summary>

![Open Magisk settings](https://user-images.githubusercontent.com/5947035/161061257-680c784b-b476-432d-8dfd-2528fe239346.png)

![Enable Zygisk](https://user-images.githubusercontent.com/5947035/161061268-3367d668-cbbd-441d-9e6d-a4cbc3978b3e.png)

![Go back to Magisk main screen](https://user-images.githubusercontent.com/5947035/161061273-329e3f8a-c957-4005-a8f7-2056b1866b08.png)

![Open Magisk modules](https://user-images.githubusercontent.com/5947035/161061277-1ada3a87-d0cb-44c0-9edd-77b00669759c.png)

![Install from storage](https://user-images.githubusercontent.com/5947035/161061283-8e3d6ed2-ca36-4825-bca4-fbb9f9185f68.png)

![Select AdGuard certificate module](https://user-images.githubusercontent.com/5947035/161061285-4ea302ad-99ec-4619-be05-3b83f64b9e4f.png)

![Reboot the device](https://user-images.githubusercontent.com/5947035/161061291-54ad008f-4c76-4ee3-975d-307fd0fe7220.png)

</details>


[latestrelease]: https://github.com/AdguardTeam/adguardcert/releases/latest/

## Chrome and Chromium-based browsers

Chrome (and subsequently many other Chromium-based browsers)
has recently started requiring CT logs for CA certs found in the **System store**.
This module copies AdGuard's CA certificate from the **User store** to the **System store**.
It also contains a Zygisk module that reverts any modifications done by Magisk for
[certain browsers](./zygisk_module/jni/browsers.inc).
This way the browsers only find AdGuard's certificate in the User store
and don't complain about the missing CT log, while other apps continue to use the
same certificate from the System store.

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
