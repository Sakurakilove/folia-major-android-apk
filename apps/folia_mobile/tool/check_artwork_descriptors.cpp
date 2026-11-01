#include "../android/app/src/main/cpp/artwork/artwork_fd.h"
#include <cassert>
#include <cerrno>
#include <fcntl.h>
#include <thread>
#include <unistd.h>

// Small native ownership contract: an Activity may close its scope while an already claimed image buffer still needs its own descriptor.
int main() {
    assert(folia_artwork_abi_version() == 1);
    int pipe_fds[2]; assert(::pipe(pipe_fds) == 0);
    const auto scope = folia_artwork_create_scope(); assert(scope != 0);
    const auto ticket = folia_artwork_register(scope, pipe_fds[0]); assert(ticket != 0);
    ::close(pipe_fds[0]);
    void* lease = folia_artwork_claim(ticket); assert(lease != nullptr);
    assert(folia_artwork_claim(ticket) == nullptr);
    const int fd = folia_artwork_lease_fd(lease); assert(fd >= 0);
    folia_artwork_release_scope(scope);
    assert(::write(pipe_fds[1], "x", 1) == 1);
    char value = 0; assert(::read(fd, &value, 1) == 1 && value == 'x');
    folia_artwork_close_lease(lease); errno = 0;
    assert(::fcntl(fd, F_GETFD) == -1 && errno == EBADF);
    assert(folia_artwork_register(scope, pipe_fds[1]) == 0);
    const auto second = folia_artwork_create_scope();
    const auto abandoned = folia_artwork_register(second, pipe_fds[1]); assert(abandoned != 0);
    folia_artwork_release_scope(second);
    assert(folia_artwork_claim(abandoned) == nullptr);
    folia_artwork_release_ticket(abandoned);
    const auto third = folia_artwork_create_scope();
    const auto racing = folia_artwork_register(third, pipe_fds[1]); assert(racing != 0);
    void* claimed = nullptr;
    std::thread claimant([&] { claimed = folia_artwork_claim(racing); });
    std::thread closer([&] { folia_artwork_release_scope(third); });
    claimant.join(); closer.join();
    if (claimed) { assert(::fcntl(folia_artwork_lease_fd(claimed), F_GETFD) >= 0); folia_artwork_close_lease(claimed); }
    ::close(pipe_fds[1]);
    const int memory = folia_artwork_memory_file();
    if (memory >= 0) {
        assert(::write(memory, "png", 3) == 3); assert(::lseek(memory, 0, SEEK_SET) == 0);
        char bytes[3]; assert(::read(memory, bytes, 3) == 3); ::close(memory);
    }
}
