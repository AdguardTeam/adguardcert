#include <memory>
#include <type_traits>
#include <string>
#include <string_view>

#include <dirent.h>

#include <android/log.h>

#define LOG_TAG "AdGuardCertificate"

#ifndef NDEBUG
#define dbglog(fmt_, ...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, "%s(): " fmt_, __func__, ##__VA_ARGS__)
#else
#define dbglog(fmt_, ...) ((void) fmt_)
#endif

#define warnlog(fmt_, ...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, "%s(): " fmt_, __func__, ##__VA_ARGS__)

namespace ag {

template<auto Func>
using Ftor = std::integral_constant<decltype(Func), Func>;
using Dir = std::unique_ptr<DIR, Ftor<&closedir>>;

int read_int(int fd);
std::string read_string(int fd);

void write_int(int fd, int v);
void write_string(int fd, std::string_view s);

}
