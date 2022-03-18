#include "common.h"
#include <unistd.h>

int ag::read_int(int fd) {
    int i;
    if (read(fd, &i, sizeof(i)) != sizeof(i)) {
        return INT_MIN;
    }
    return i;
}

std::string ag::read_string(int fd) {
    size_t size = 0;
    if (read(fd, &size, sizeof(size)) != sizeof(size)) {
        return "";
    }
    std::string s;
    s.resize(size);
    if (read(fd, s.data(), s.size()) != s.size()) {
        return "";
    }
    return s;
}

void ag::write_int(int fd, int v) {
    write(fd, &v, sizeof(v));
}

void ag::write_string(int fd, std::string_view s) {
    size_t size = s.size();
    write(fd, &size, sizeof(size));
    write(fd, s.data(), size);
}
