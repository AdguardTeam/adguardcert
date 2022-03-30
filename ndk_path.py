#!/usr/bin/env python3

import os

def get_ndk_path():
    sdk_path = os.environ.get('ANDROID_HOME')
    if os.path.isdir(sdk_path):
        path = os.path.join(sdk_path, 'ndk')
        if os.path.isdir(path):
            # Android Studio can install multiple ndk versions in 'ndk'.
            # Find the newest one.
            ndk_version = None
            for name in os.listdir(path):
                if not ndk_version or ndk_version < name:
                    ndk_version = name
            if ndk_version:
                return os.path.join(path, ndk_version)
    ndk_path = os.path.join(sdk_path, 'ndk-bundle')
    if os.path.isdir(ndk_path):
        return ndk_path
    return None

print(get_ndk_path())
