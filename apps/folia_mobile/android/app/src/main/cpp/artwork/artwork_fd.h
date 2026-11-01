#pragma once
#include <cstdint>
#include <cstddef>

// A platform reply carries only a ticket. Claim atomically transfers a duplicated descriptor into a Dart-owned native lease, never an unguarded integer fd.
extern "C" {
std::uint32_t folia_artwork_abi_version();
int folia_artwork_memory_file();
std::uint64_t folia_artwork_create_scope();
std::uint64_t folia_artwork_register(std::uint64_t scope, int fd);
void folia_artwork_release_ticket(std::uint64_t ticket);
void folia_artwork_release_scope(std::uint64_t scope);
void* folia_artwork_claim(std::uint64_t ticket);
int folia_artwork_lease_fd(void* lease);
void folia_artwork_close_lease(void* lease);
void* folia_artwork_allocate(std::size_t bytes);
void folia_artwork_release(void* bytes);
void* folia_artwork_decode_data(const std::uint8_t* bytes, std::size_t length);
const std::uint8_t* folia_artwork_data_bytes(void* data);
std::size_t folia_artwork_data_size(void* data);
void folia_artwork_close_data(void* data);
}
