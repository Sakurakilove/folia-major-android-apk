#include "artwork_fd.h"
#include <atomic>
#include <cerrno>
#include <fcntl.h>
#include <mutex>
#include <new>
#include <unistd.h>
#include <sys/syscall.h>
#include <unordered_map>
#include <unordered_set>
#ifdef __ANDROID__
#include <jni.h>
#endif

// Closing an Activity can invalidate unclaimed tickets, but cannot close/reuse a descriptor already being read by the engine's asynchronous buffer loader.
namespace {
struct Entry { std::uint64_t scope; int fd; };
struct Lease { int fd; ~Lease() { if (fd >= 0) ::close(fd); } };
std::mutex gate;
std::unordered_map<std::uint64_t, Entry> pending;
std::unordered_set<std::uint64_t> scopes;
std::atomic<std::uint64_t> sequence{1};
std::uint64_t next_id() {
    auto value = sequence.fetch_add(1, std::memory_order_relaxed) & 0x7fffffffffffffffULL;
    while (!value) value = sequence.fetch_add(1, std::memory_order_relaxed) & 0x7fffffffffffffffULL;
    return value;
}
}

extern "C" {
std::uint32_t folia_artwork_abi_version() { return 1; }
int folia_artwork_memory_file() {
#ifdef SYS_memfd_create
    return static_cast<int>(::syscall(SYS_memfd_create, "folia-artwork", 1U));
#else
    return -1;
#endif
}
std::uint64_t folia_artwork_create_scope() {
    try {
        std::lock_guard<std::mutex> lock(gate);
        auto scope = next_id();
        while (scopes.find(scope) != scopes.end()) scope = next_id();
        scopes.insert(scope); return scope;
    } catch (...) { return 0; }
}
std::uint64_t folia_artwork_register(std::uint64_t scope, int fd) {
    int owned;
    do { owned = ::fcntl(fd, F_DUPFD_CLOEXEC, 0); } while (owned < 0 && errno == EINTR);
    if (owned < 0) return 0;
    try {
        std::lock_guard<std::mutex> lock(gate);
        if (scopes.find(scope) == scopes.end()) { ::close(owned); return 0; }
        auto ticket = next_id();
        while (pending.find(ticket) != pending.end()) ticket = next_id();
        pending.emplace(ticket, Entry{scope, owned});
        return ticket;
    } catch (...) { ::close(owned); return 0; }
}
void folia_artwork_release_ticket(std::uint64_t ticket) {
    std::lock_guard<std::mutex> lock(gate);
    const auto found = pending.find(ticket);
    if (found == pending.end()) return;
    ::close(found->second.fd); pending.erase(found);
}
void folia_artwork_release_scope(std::uint64_t scope) {
    std::lock_guard<std::mutex> lock(gate);
    scopes.erase(scope);
    for (auto it = pending.begin(); it != pending.end();) {
        if (it->second.scope == scope) { ::close(it->second.fd); it = pending.erase(it); }
        else ++it;
    }
}
void* folia_artwork_claim(std::uint64_t ticket) {
    std::lock_guard<std::mutex> lock(gate);
    const auto found = pending.find(ticket);
    if (found == pending.end()) return nullptr;
    auto* lease = new (std::nothrow) Lease{found->second.fd};
    if (!lease) return nullptr;
    pending.erase(found); return lease;
}
int folia_artwork_lease_fd(void* lease) { return lease ? static_cast<Lease*>(lease)->fd : -1; }
void folia_artwork_close_lease(void* lease) { delete static_cast<Lease*>(lease); }
}

#ifdef __ANDROID__
extern "C" JNIEXPORT jint JNICALL
Java_top_izuna_foliamajor_next_artwork_NativeArtworkDescriptors_createMemoryFile(JNIEnv*, jobject) {
    return folia_artwork_memory_file();
}
extern "C" JNIEXPORT jlong JNICALL
Java_top_izuna_foliamajor_next_artwork_NativeArtworkDescriptors_createScope(JNIEnv*, jobject) {
    return static_cast<jlong>(folia_artwork_create_scope());
}
extern "C" JNIEXPORT jlong JNICALL
Java_top_izuna_foliamajor_next_artwork_NativeArtworkDescriptors_registerFd(JNIEnv*, jobject, jlong scope, jint fd) {
    return static_cast<jlong>(folia_artwork_register(static_cast<std::uint64_t>(scope), fd));
}
extern "C" JNIEXPORT void JNICALL
Java_top_izuna_foliamajor_next_artwork_NativeArtworkDescriptors_releaseTicket(JNIEnv*, jobject, jlong ticket) {
    folia_artwork_release_ticket(static_cast<std::uint64_t>(ticket));
}
extern "C" JNIEXPORT void JNICALL
Java_top_izuna_foliamajor_next_artwork_NativeArtworkDescriptors_releaseScope(JNIEnv*, jobject, jlong scope) {
    folia_artwork_release_scope(static_cast<std::uint64_t>(scope));
}
#endif
