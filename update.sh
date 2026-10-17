#!/bin/bash

VERSION=$(sed -ne "s/version=\(.*\)/\1/gp" module/module.prop)

case "$VERSION" in
*-*)
    echo "Skipping update.json rewrite for prerelease $VERSION"
    exit 0
    ;;
*)
    git checkout -B master origin/master
    ./generate_changelog.sh
    cat module/module.prop | (
    IFS="="
    while read k v; do
        read $k <<< "$v"
    done
    cat << EOF > update.json
{
  "version": "$version",
  "versionCode": $versionCode,
  "zipUrl": "https://github.com/larsmartens/adguardcert/releases/download/$version/adguardcert-$version.zip",
  "changelog": "https://raw.githubusercontent.com/larsmartens/adguardcert/master/changelog.md"
}
EOF
    )
    git add update.json changelog.md
    git commit -m "skipci: Update update.json" || true
    ;;
esac
