#include <sys/sendfile.h>
#include <linux/fs.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <libgen.h>

#include <utils.hpp>
#include <selinux.hpp>

using namespace std;

ssize_t fd_path(int fd, char *path, size_t size) {
    snprintf(path, size, "/proc/self/fd/%d", fd);
    return xreadlink(path, path, size);
}

int fd_pathat(int dirfd, const char *name, char *path, size_t size) {
    if (fd_path(dirfd, path, size) < 0)
        return -1;
    auto len = strlen(path);
    path[len] = '/';
    strlcpy(path + len + 1, name, size - len - 1);
    return 0;
}

int mkdirs(string path, mode_t mode) {
    errno = 0;
    for (char *p = path.data() + 1; *p; ++p) {
        if (*p == '/') {
            *p = '\0';
            if (mkdir(path.data(), mode) == -1) {
                if (errno != EEXIST)
                    return -1;
            }
            *p = '/';
        }
    }
    if (mkdir(path.data(), mode) == -1) {
        if (errno != EEXIST)
            return -1;
    }
    return 0;
}

template <typename Func>
static void post_order_walk(int dirfd, const Func &fn) {
    auto dir = xopen_dir(dirfd);
    if (!dir) return;

    for (dirent *entry; (entry = xreaddir(dir.get()));) {
        if (entry->d_type == DT_DIR)
            post_order_walk(xopenat(dirfd, entry->d_name, O_RDONLY | O_CLOEXEC), fn);
        fn(dirfd, entry);
    }
}

template <typename Func>
static void pre_order_walk(int dirfd, const Func &fn) {
    auto dir = xopen_dir(dirfd);
    if (!dir) return;

    for (dirent *entry; (entry = xreaddir(dir.get()));) {
        if (!fn(dirfd, entry))
            continue;
        if (entry->d_type == DT_DIR)
            pre_order_walk(xopenat(dirfd, entry->d_name, O_RDONLY | O_CLOEXEC), fn);
    }
}

static void remove_at(int dirfd, struct dirent *entry) {
    unlinkat(dirfd, entry->d_name, entry->d_type == DT_DIR ? AT_REMOVEDIR : 0);
}

void rm_rf(const char *path) {
    struct stat st;
    if (lstat(path, &st) < 0)
        return;
    if (S_ISDIR(st.st_mode))
        frm_rf(xopen(path, O_RDONLY | O_CLOEXEC));
    remove(path);
}

void frm_rf(int dirfd) {
    post_order_walk(dirfd, remove_at);
}

void mv_path(const char *src, const char *dest) {
    file_attr attr;
    getattr(src, &attr);
    if (S_ISDIR(attr.st.st_mode)) {
        if (access(dest, F_OK) != 0) {
            xmkdirs(dest, 0);
            setattr(dest, &attr);
        }
        mv_dir(xopen(src, O_RDONLY | O_CLOEXEC), xopen(dest, O_RDONLY | O_CLOEXEC));
    } else{
        xrename(src, dest);
    }
    rmdir(src);
}

void mv_dir(int src, int dest) {
    auto dir = xopen_dir(src);
    run_finally f([=]{ close(dest); });
    for (dirent *entry; (entry = xreaddir(dir.get()));) {
        switch (entry->d_type) {
        case DT_DIR:
            if (faccessat(dest, entry->d_name, F_OK, 0) == 0) {
                // Destination folder exists, needs recursive move
                int newsrc = xopenat(src, entry->d_name, O_RDONLY | O_CLOEXEC);
                int newdest = xopenat(dest, entry->d_name, O_RDONLY | O_CLOEXEC);
                mv_dir(newsrc, newdest);
                unlinkat(src, entry->d_name, AT_REMOVEDIR);
                break;
            }
            // Else fall through
        case DT_LNK:
        case DT_REG:
            renameat(src, entry->d_name, dest, entry->d_name);
            break;
        }
    }
}

void cp_afc(const char *src, const char *dest) {
    file_attr a;
    getattr(src, &a);

    if (S_ISDIR(a.st.st_mode)) {
        xmkdirs(dest, 0);
        clone_dir(xopen(src, O_RDONLY | O_CLOEXEC), xopen(dest, O_RDONLY | O_CLOEXEC));
    } else{
        unlink(dest);
        if (S_ISREG(a.st.st_mode)) {
            int sfd = xopen(src, O_RDONLY | O_CLOEXEC);
            int dfd = xopen(dest, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0);
            xsendfile(dfd, sfd, nullptr, a.st.st_size);
            close(sfd);
            close(dfd);
        } else if (S_ISLNK(a.st.st_mode)) {
            char buf[4096];
            xreadlink(src, buf, sizeof(buf));
            xsymlink(buf, dest);
        }
    }
    setattr(dest, &a);
}

void clone_dir(int src, int dest) {
    auto dir = xopen_dir(src);
    run_finally f([&]{ close(dest); });
    for (dirent *entry; (entry = xreaddir(dir.get()));) {
        file_attr a;
        getattrat(src, entry->d_name, &a);
        switch (entry->d_type) {
            case DT_DIR: {
                xmkdirat(dest, entry->d_name, 0);
                setattrat(dest, entry->d_name, &a);
                int sfd = xopenat(src, entry->d_name, O_RDONLY | O_CLOEXEC);
                int dst = xopenat(dest, entry->d_name, O_RDONLY | O_CLOEXEC);
                clone_dir(sfd, dst);
                break;
            }
            case DT_REG: {
                int sfd = xopenat(src, entry->d_name, O_RDONLY | O_CLOEXEC);
                int dfd = xopenat(dest, entry->d_name, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0);
                xsendfile(dfd, sfd, nullptr, a.st.st_size);
                fsetattr(dfd, &a);
                close(dfd);
                close(sfd);
                break;
            }
            case DT_LNK: {
                char buf[4096];
                xreadlinkat(src, entry->d_name, buf, sizeof(buf));
                xsymlinkat(buf, dest, entry->d_name);
                setattrat(dest, entry->d_name, &a);
                break;
            }
        }
    }
}

void link_path(const char *src, const char *dest) {
    link_dir(xopen(src, O_RDONLY | O_CLOEXEC), xopen(dest, O_RDONLY | O_CLOEXEC));
}

void link_dir(int src, int dest) {
    auto dir = xopen_dir(src);
    run_finally f([&]{ close(dest); });
    for (dirent *entry; (entry = xreaddir(dir.get()));) {
        if (entry->d_type == DT_DIR) {
            file_attr a;
            getattrat(src, entry->d_name, &a);
            xmkdirat(dest, entry->d_name, 0);
            setattrat(dest, entry->d_name, &a);
            int sfd = xopenat(src, entry->d_name, O_RDONLY | O_CLOEXEC);
            int dfd = xopenat(dest, entry->d_name, O_RDONLY | O_CLOEXEC);
            link_dir(sfd, dfd);
        } else {
            xlinkat(src, entry->d_name, dest, entry->d_name, 0);
        }
    }
}

int getattr(const char *path, file_attr *a) {
    if (xlstat(path, &a->st) == -1)
        return -1;
    char *con;
    if (lgetfilecon(path, &con) == -1)
        return -1;
    strcpy(a->con, con);
    freecon(con);
    return 0;
}

int getattrat(int dirfd, const char *name, file_attr *a) {
    char path[4096];
    fd_pathat(dirfd, name, path, sizeof(path));
    return getattr(path, a);
}

int fgetattr(int fd, file_attr *a) {
    if (xfstat(fd, &a->st) < 0)
        return -1;
    char *con;
    if (fgetfilecon(fd, &con) < 0)
        return -1;
    strcpy(a->con, con);
    freecon(con);
    return 0;
}

int setattr(const char *path, file_attr *a) {
    if (chmod(path, a->st.st_mode & 0777) < 0)
        return -1;
    if (chown(path, a->st.st_uid, a->st.st_gid) < 0)
        return -1;
    if (a->con[0] && lsetfilecon(path, a->con) < 0)
        return -1;
    return 0;
}

int setattrat(int dirfd, const char *name, file_attr *a) {
    char path[4096];
    fd_pathat(dirfd, name, path, sizeof(path));
    return setattr(path, a);
}

int fsetattr(int fd, file_attr *a) {
    if (fchmod(fd, a->st.st_mode & 0777) < 0)
        return -1;
    if (fchown(fd, a->st.st_uid, a->st.st_gid) < 0)
        return -1;
    if (a->con[0] && fsetfilecon(fd, a->con) < 0)
        return -1;
    return 0;
}

void clone_attr(const char *src, const char *dest) {
    file_attr a;
    getattr(src, &a);
    setattr(dest, &a);
}

void fclone_attr(int src, int dest) {
    file_attr a;
    fgetattr(src, &a);
    fsetattr(dest, &a);
}

void *__mmap(const char *filename, size_t *size, bool rw) {
    int fd = xopen(filename, (rw ? O_RDWR : O_RDONLY) | O_CLOEXEC);
    if (fd < 0) {
        *size = 0;
        return nullptr;
    }
    struct stat st;
    void *buf;
    if (fstat(fd, &st)) {
        *size = 0;
        return nullptr;
    }
    if (S_ISBLK(st.st_mode))
        ioctl(fd, BLKGETSIZE64, size);
    else
        *size = st.st_size;
    buf = *size > 0 ? xmmap(nullptr, *size, PROT_READ | (rw ? PROT_WRITE : 0), MAP_SHARED, fd, 0) : nullptr;
    close(fd);
    return buf;
}

void fd_full_read(int fd, void **buf, size_t *size) {
    *size = lseek(fd, 0, SEEK_END);
    lseek(fd, 0, SEEK_SET);
    *buf = xmalloc(*size + 1);
    xxread(fd, *buf, *size);
    ((char *) *buf)[*size] = '\0';
}

void full_read(const char *filename, void **buf, size_t *size) {
    int fd = xopen(filename, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        *buf = nullptr;
        *size = 0;
        return;
    }
    fd_full_read(fd, buf, size);
    close(fd);
}

string fd_full_read(int fd) {
    char buf[4096];
    string str;
    for (ssize_t len; (len = xread(fd, buf, sizeof(buf))) > 0;)
        str.insert(str.end(), buf, buf + len);
    return str;
}

string full_read(const char *filename) {
    int fd = xopen(filename, O_RDONLY | O_CLOEXEC);
    run_finally f([=]{ close(fd); });
    return fd < 0 ? "" : fd_full_read(fd);
}

void write_zero(int fd, size_t size) {
    char buf[4096] = {0};
    size_t len;
    while (size > 0) {
        len = sizeof(buf) > size ? size : sizeof(buf);
        write(fd, buf, len);
        size -= len;
    }
}

void file_readline(bool trim, const char *file, const function<bool(string_view)> &fn) {
    FILE *fp = xfopen(file, "re");
    if (fp == nullptr)
        return;
    size_t len = 1024;
    char *buf = (char *) malloc(len);
    char *start;
    ssize_t read;
    while ((read = getline(&buf, &len, fp)) >= 0) {
        start = buf;
        if (trim) {
            while (read && "\n\r "sv.find(buf[read - 1]) != string::npos)
                --read;
            buf[read] = '\0';
            while (*start == ' ')
                ++start;
        }
        if (!fn(start))
            break;
    }
    fclose(fp);
    free(buf);
}

void parse_prop_file(const char *file, const function<bool(string_view, string_view)> &fn) {
    file_readline(true, file, [&](string_view line_view) -> bool {
        char *line = (char *) line_view.data();
        if (line[0] == '#')
            return true;
        char *eql = strchr(line, '=');
        if (eql == nullptr || eql == line)
            return true;
        *eql = '\0';
        return fn(line, eql + 1);
    });
}

void parse_mnt(const char *file, const function<bool(mntent*)> &fn) {
    auto fp = sFILE(setmntent(file, "re"), endmntent);
    if (fp) {
        mntent mentry{};
        char buf[4096];
        while (getmntent_r(fp.get(), &mentry, buf, sizeof(buf))) {
            if (!fn(&mentry))
                break;
        }
    }
}

void backup_folder(const char *dir, vector<raw_file> &files) {
    char path[4096];
    xrealpath(dir, path);
    int len = strlen(path);
    pre_order_walk(xopen(dir, O_RDONLY), [&](int dfd, dirent *entry) -> bool {
        int fd = xopenat(dfd, entry->d_name, O_RDONLY);
        if (fd < 0)
            return false;
        run_finally f([&]{ close(fd); });
        if (fd_path(fd, path, sizeof(path)) < 0)
            return false;
        raw_file file;
        file.path = path + len + 1;
        if (fgetattr(fd, &file.attr) < 0)
            return false;
        if (entry->d_type == DT_REG) {
            fd_full_read(fd, file.buf, file.sz);
        } else if (entry->d_type == DT_LNK) {
            xreadlinkat(dfd, entry->d_name, path, sizeof(path));
            file.sz = strlen(path) + 1;
            file.buf = (uint8_t *) xmalloc(file.sz);
            memcpy(file.buf, path, file.sz);
        }
        files.emplace_back(std::move(file));
        return true;
    });
}

void restore_folder(const char *dir, vector<raw_file> &files) {
    string base(dir);
    // Pre-order means folders will always be first
    for (raw_file &file : files) {
        string path = base + "/" + file.path;
        if (S_ISDIR(file.attr.st.st_mode)) {
            mkdirs(path.data(), 0);
        } else if (S_ISREG(file.attr.st.st_mode)) {
            auto fp = xopen_file(path.data(), "we");
            fwrite(file.buf, 1, file.sz, fp.get());
        } else if (S_ISLNK(file.attr.st.st_mode)) {
            symlink((char *)file.buf, path.data());
        }
        setattr(path.data(), &file.attr);
    }
}

sDIR make_dir(DIR *dp) {
    return sDIR(dp, [](DIR *dp){ return dp ? closedir(dp) : 1; });
}

sFILE make_file(FILE *fp) {
    return sFILE(fp, [](FILE *fp){ return fp ? fclose(fp) : 1; });
}
