# AdGuard Certificate

Based on [Move Certificates](https://github.com/Magisk-Modules-Repo/movecert).

This Magisk module supplements [AdGuard for Android][agandroid] and allows installing
AdGuard's CA certificate to the System store on rooted devices.

**Attention**
If you're using AdGuard for Android v4.2 Nightly 10 or newer, use the beta version of
this magisk module: https://github.com/AdguardTeam/adguardcert/releases/tag/v2.0-beta4.

## Explanation

Chrome (and subsequently many other Chromium-based browsers)
has recently started requiring Certificate Transparency logs
for CA certs found in the **system certificate store**.

If your device is rooted, and you want AdGuard's CA certificate to be installed
in the **system store** , then AdGuard will generate two CA certificates and ask you
to install both of them in the **user store**. This module moves one of them to the
**system store**. The certificate that is left in the **user store** is cross-signed
with the one that goes into the **system store**. This allows apps that don't trust
user certificates to still accept AdGuard's certificate, while apps that do trust
user certificates (like Chrome or other browsers) will construct a shorter validation
path to the certificate stored in the **user store**. And since it is stored in the
**user store**, they won't require CT logs.

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
3. Go to *Magisk -> Modules -> Install from storage* and select the downloaded `.zip` file.
4. Reboot.

If a new version comes out, repeat steps 2-4 to update the module.

The module does its work during the system boot. If your AdGuard certificate(s) change,
you'll have to reboot the device for the new certificate to be copied to the system store.

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

[latestrelease]: https://github.com/AdguardTeam/adguardcert/releases/latest/

## Building
```shell
./dist.sh
```

How to release a new version:
1. Push a new tag with a name like `v*`.
2. A new release will be automatically created.
