#include <atomic>
#include <mutex>
#include <memory>
#include <unordered_map>

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#include "common.h"
#include "zygisk.hpp"

#define APP_ID(uid) (uid % 100000)

using Map = std::unordered_map<int, std::string>;
static std::shared_ptr<Map> g_app_id_to_pkg;

static void rescan_packages() {
    struct stat st{};
    static std::atomic_int64_t packages_xml_ino{0};

    stat("/data/system/packages.xml", &st);

    if (packages_xml_ino == st.st_ino) {
        dbglog("Packages unchanged, no need to rescan");
        return;
    }

    static std::mutex rescan_mutex;
    std::scoped_lock l(rescan_mutex);

    if (packages_xml_ino == st.st_ino) {
        dbglog("Packages unchanged, no need to rescan");
        return;
    }

    dbglog("Rescanning packages");

    packages_xml_ino = st.st_ino;

    ag::Dir data_dir;
    data_dir.reset(opendir("/data/user_de"));

    if (!data_dir) {
        dbglog("Failed to open /data/user_de");
        data_dir.reset(opendir("/data/user"));
        if (!data_dir) {
            warnlog("Failed to open /data/user, can't scan apps");
            return;
        }
    }

    Map app_id_to_pkg;
    dirent *entry;
    while ((entry = readdir(data_dir.get()))) {
        // For each user
        int dir_fd = openat(dirfd(data_dir.get()), entry->d_name, O_RDONLY);
        if (ag::Dir dir{fdopendir(dir_fd)}) {
            while ((entry = readdir(dir.get()))) {
                // For each package
                struct stat st{};
                fstatat(dir_fd, entry->d_name, &st, 0);
                int uid = st.st_uid;
                int app_id = APP_ID(uid);
                if (app_id_to_pkg.count(app_id)) {
                    // This app ID has been handled
                    continue;
                }
                dbglog("uid: %d, app_id: %d, package: %s", uid, app_id, entry->d_name);
                app_id_to_pkg.emplace(app_id, entry->d_name);
            }
        } else {
            close(dir_fd);
        }
    }

    std::atomic_store(&g_app_id_to_pkg, std::make_shared<Map>(std::move(app_id_to_pkg)));
}

static void companion_handler(int fd) {
    rescan_packages();

    auto app_id_to_pkg = std::atomic_load(&g_app_id_to_pkg);

    int uid = ag::read_int(fd);

    auto it = app_id_to_pkg->find(APP_ID(uid));
    if (it == app_id_to_pkg->end()) {
        dbglog("uid: %d, app_id: %d, package not found", uid, APP_ID(uid));
        ag::write_string(fd, "");
    } else {
        dbglog("uid: %d, app_id: %d, package: %s", uid, APP_ID(uid), it->second.c_str());
        ag::write_string(fd, it->second);
    }
}

REGISTER_ZYGISK_COMPANION(companion_handler)
