# Building from source

Clone the two repos at the correct commits, then apply the patches.

## 1. Clone

```
clone-git-repos.bat
```

To revert to baseline at any point: `reset-git-repos.bat`.

## 2. Apply patches

```
apply-patches.bat
```

## 3. Build

**RPCS3** — see `GIT\rpcs3\BUILDING.md` (Visual Studio 2022). Copy `GIT\rpcs3\bin\` output to `BIN\_app\RPCS3\`.

**RPCN** — requires Rust (MSVC ABI), Strawberry Perl, NASM, and protoc on PATH.
```
cd GIT\rpcn
cargo build --release
copy target\release\rpcn.exe ..\..\BIN\_app\rpcn\rpcn.exe
```
