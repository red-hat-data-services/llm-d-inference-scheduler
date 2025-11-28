# Docker Konflux Dependencies

This document explains how to update the tokenizers git submodule and Rust dependencies (`Cargo.toml` and `Cargo.lock`) used for building tokenizers in the Konflux hermetic build environment.

## Overview

The `tokenizers` directory is a git submodule pointing to the [daulet/tokenizers](https://github.com/daulet/tokenizers) repository. The `Cargo.toml` and `Cargo.lock` files in the root directory are used by cachi2 to vendor Rust dependencies during the prefetch step. These dependencies are then used when building the tokenizers library from source in the Dockerfile using the submodule.

## Updating the Tokenizers Submodule

When you need to update to a new version of tokenizers, follow these steps:

### 1. Update the git submodule

Update the submodule to point to the desired version tag:

```bash
cd tokenizers
git fetch origin
git checkout v1.22.2  # Replace with your desired version tag
cd ..
git add tokenizers
git commit -m "Update tokenizers submodule to v1.22.2"
```

### 2. Update Cargo.toml and Cargo.lock

The root `Cargo.toml` and `Cargo.lock` files are used by cachi2 to vendor Rust dependencies. You need to update them to match the version in the submodule. You can either:

**Option A: Copy from the submodule** (recommended):

```bash
cp tokenizers/Cargo.toml Cargo.toml
cp tokenizers/Cargo.lock Cargo.lock
```

**Option B: Download from the repository**:

```bash
# Replace v1.22.2 with your desired version tag
curl -o Cargo.toml https://raw.githubusercontent.com/daulet/tokenizers/v1.22.2/Cargo.toml
curl -o Cargo.lock https://raw.githubusercontent.com/daulet/tokenizers/v1.22.2/Cargo.lock
```

**Note:** You may need to adjust the `Cargo.toml` file:

- Ensure the `[package]` name and version match your needs
- Verify the `[lib]` section has `crate-type = ["staticlib"]` for building a static library
- Remove any `[[bench]]` sections if the corresponding bench files don't exist (to avoid cargo errors)

### 3. Ensure src/lib.rs exists

The `Cargo.toml` file defines a library, so you need a minimal `src/lib.rs` file:

```bash
mkdir -p src
cat > src/lib.rs << 'EOF'
// Minimal library file required by Cargo.toml
// This file exists to allow cargo vendor to work during the prefetch step
// The actual tokenizers library is built from source in the Dockerfile
EOF
```

### 4. Commit and test the changes

Commit the updated submodule, `Cargo.toml`, `Cargo.lock`, and `src/lib.rs` files:

```bash
git add tokenizers Cargo.toml Cargo.lock src/lib.rs
git commit -m "Update tokenizers submodule and Rust dependencies to v1.22.2"
```

### 5. Verify in Konflux build

Create a pull request and test the changes:

1. Push your changes to a branch
2. Create a pull request
3. Comment `/build-konflux` in the PR to trigger the Konflux build
4. Verify that the `prefetch-dependencies` task completes successfully
   - The task should run `cargo vendor --locked --versioned-dirs --no-delete`
   - All Rust dependencies should be vendored without errors
   - The build should proceed to the next steps

### 6. No Dockerfile changes needed

Since we're using a git submodule, no changes to `Dockerfile.konflux` are needed when updating the tokenizers version. The Dockerfile automatically builds from the `tokenizers/` submodule directory.

## Current Version

- **Tokenizers version**: v1.22.2 (check the submodule commit: `cd tokenizers && git describe --tags`)
- **Submodule**: `tokenizers/` directory
- **Cargo.toml source**: https://github.com/daulet/tokenizers/blob/v1.22.2/Cargo.toml
- **Cargo.lock source**: https://github.com/daulet/tokenizers/blob/v1.22.2/Cargo.lock

## Troubleshooting

### Error: "can't find library `tokenizers`"

**Solution:** Ensure `src/lib.rs` exists. This file is required by cargo to parse the package structure.

### Error: "can't find `decode_benchmark` bench"

**Solution:** Remove the `[[bench]]` section from `Cargo.toml` if the bench file doesn't exist.

### Error: "Cargo.lock is out of sync"

**Solution:** Regenerate `Cargo.lock` by running `cargo generate-lockfile` in a container with cargo installed, or download the correct version from the tokenizers repository.

### Error: "cargo vendor --locked failed"

**Solution:**

1. Ensure `Cargo.lock` matches `Cargo.toml`
2. Verify `src/lib.rs` exists
3. Check the `prefetch-dependencies` task logs in the Konflux build for specific error messages
4. Ensure the version tag in the curl commands matches the actual tokenizers version you're using

## Related Files

- `tokenizers/` - Git submodule containing the tokenizers source code
- `Cargo.toml` - Rust package manifest (used by cachi2 for vendoring dependencies)
- `Cargo.lock` - Locked dependency versions (used by cachi2 for vendoring dependencies)
- `src/lib.rs` - Minimal library file required by Cargo.toml
- `Dockerfile.konflux` - Build file that builds from the submodule using vendored dependencies
- `.gitmodules` - Git submodule configuration
