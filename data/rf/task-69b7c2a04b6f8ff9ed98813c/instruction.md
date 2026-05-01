The memory management code in `src/libnetdata/libnetdata.c` has turned into a monolith. Memory allocation wrappers, mmap/munmap functions, madvise helpers, and all their related globals are crammed into one file alongside unrelated utilities. It is hard to navigate and maintain. On top of that, memory alignment logic is duplicated across three places (`aral.c`, `onewayalloc.c`, and `libnetdata.h` each have their own version), and the system page size is retrieved differently in `aral.c` and `onewayalloc.c` with no Windows support in either.

Can you split the memory management code into proper modules under `src/libnetdata/memory/`? The allocation wrappers (mallocz, callocz, freez, etc.) and the mmap related code, including helpers like the madvise wrappers, should each get their own source and header files. For the mmap layer, rename `netdata_mmap` to `nd_mmap_advanced` and `netdata_munmap` to `nd_munmap`, and introduce a new thin `nd_mmap` wrapper around the system `mmap()` that tracks both the number of active mappings and total mapped size. All direct `mmap()`/`munmap()` calls across the codebase should go through the new wrappers instead.

Consolidate the duplicated alignment implementations into a single header under `src/libnetdata/memory/`, providing unified `memory_alignment()` and `natural_alignment()` functions that replace `struct_natural_alignment()` and the other variants.

Create a centralized `os_get_system_page_size()` under `src/libnetdata/os/` to replace the ad-hoc `sysconf` calls, and add Windows support. Wire everything into `CMakeLists.txt` and the include chain through `libnetdata.h`.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

- Path: `src/libnetdata/memory/nd-mmap.c`
- Name: `nd_mmap`
- Type: function
- Input: `void *addr, size_t len, int prot, int flags, int fd, off_t offset`
- Output: `void *`
- Description: Thin wrapper around the system mmap() that performs memory accounting, atomically incrementing the active mapping count and total mapped size on success.

- Path: `src/libnetdata/memory/nd-mmap.c`
- Name: `nd_mmap_advanced`
- Type: function
- Input: `const char *filename, size_t size, int flags, int ksm, bool read_only, bool dont_dump, int *open_fd`
- Output: `void *`
- Description: High-level memory mapping function that handles file-backed and anonymous mappings with optional KSM and madvise configuration. Returns NULL on failure instead of MAP_FAILED.

- Path: `src/libnetdata/memory/nd-mmap.c`
- Name: `nd_munmap`
- Type: function
- Input: `void *ptr, size_t size`
- Output: `int`
- Description: Wrapper around the system munmap() that atomically decrements the active mapping count and total mapped size on success.

- Path: `src/libnetdata/os/get_system_pagesize.c`
- Name: `os_get_system_page_size`
- Type: function
- Input: `void`
- Output: `size_t`
- Description: Returns the system page size. Uses sysconf on POSIX and GetSystemInfo on Windows. Caches the result and defaults to 4096 if the value is invalid.

- Path: `src/libnetdata/memory/alignment.h`
- Name: `natural_alignment`
- Type: function
- Input: `size_t size`
- Output: `size_t`
- Description: Returns the given size rounded up to the system's natural alignment boundary.

- Path: `src/libnetdata/memory/alignment.h`
- Name: `memory_alignment`
- Type: function
- Input: `size_t size, size_t alignment`
- Output: `size_t`
- Description: Returns the given size rounded up to the specified alignment boundary.
