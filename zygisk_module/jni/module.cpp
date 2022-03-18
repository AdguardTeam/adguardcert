#include <string>
#include <algorithm>

#include <unistd.h>

#include "common.h"
#include "zygisk.hpp"

static const std::string PACKAGES_TO_UNMOUNT[] = {
        "com.android.chrome",
        "com.chrome.canary",
        "com.chrome.beta",
        "com.chrome.dev",
};

class MyModule : public zygisk::ModuleBase {
public:
    void onLoad(zygisk::Api *api, JNIEnv *env) override {
        this->api = api;
        this->env = env;
    }

    void preAppSpecialize(zygisk::AppSpecializeArgs *args) override {
        int fd = api->connectCompanion();
        if (fd < 0) {
            warnlog("Failed to connect companion");
            return;
        }
        ag::write_int(fd, args->uid);
        std::string package = ag::read_string(fd);
        if (std::any_of(std::begin(PACKAGES_TO_UNMOUNT), std::end(PACKAGES_TO_UNMOUNT),
                        [&](const std::string &pkg) { return pkg == package; })) {
            dbglog("Forcing denylist unmount routines for package: %s", package.c_str());
            api->setOption(zygisk::Option::FORCE_DENYLIST_UNMOUNT);
        }
        api->setOption(zygisk::Option::DLCLOSE_MODULE_LIBRARY);
        close(fd);
    }

private:
    zygisk::Api *api;
    JNIEnv *env;
};

REGISTER_ZYGISK_MODULE(MyModule)
