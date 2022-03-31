#include <string>
#include <unordered_set>

#include <unistd.h>

#include "common.h"
#include "zygisk.hpp"

static const std::unordered_set<std::string> PACKAGES_TO_UNMOUNT = {
#include "browsers.inc"
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
        if (PACKAGES_TO_UNMOUNT.count(package)) {
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
