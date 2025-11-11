# Docker Konflux Dependencies

This document explains how to update the Rust dependencies (`Cargo.toml` and `Cargo.lock`) used for building tokenizers in the Konflux hermetic build environment.

## Overview

The `Cargo.toml` and `Cargo.lock` files in the root directory are used by cachi2 to vendor Rust dependencies during the prefetch step. These dependencies are then used when building the tokenizers library from source in the Dockerfile.

## Updating Cargo.toml and Cargo.lock

When you need to update to a new version of tokenizers, follow these steps:

### 1. Determine the tokenizers version

Check the version tag you want to use. For example, `v1.22.1` or `v1.22.2`.

### 2. Download Cargo.toml from the tokenizers repository

```bash
# Replace v1.22.1 with your desired version tag
curl -o Cargo.toml https://raw.githubusercontent.com/daulet/tokenizers/v1.22.1/Cargo.toml
```

**Note:** You may need to adjust the `Cargo.toml` file:

- Ensure the `[package]` name and version match your needs
- Verify the `[lib]` section has `crate-type = ["staticlib"]` for building a static library
- Remove any `[[bench]]` sections if the corresponding bench files don't exist (to avoid cargo errors)

### 3. Download Cargo.lock from the tokenizers repository

```bash
# Replace v1.22.1 with your desired version tag
curl -o Cargo.lock https://raw.githubusercontent.com/daulet/tokenizers/v1.22.1/Cargo.lock
```

### 4. Ensure src/lib.rs exists

The `Cargo.toml` file defines a library, so you need a minimal `src/lib.rs` file:

```bash
mkdir -p src
cat > src/lib.rs << 'EOF'
// Minimal library file required by Cargo.toml
// This file exists to allow cargo vendor to work during the prefetch step
// The actual tokenizers library is built from source in the Dockerfile
EOF
```

### 5. Commit and test the changes

Commit the updated `Cargo.toml`, `Cargo.lock`, and `src/lib.rs` files:

```bash
git add Cargo.toml Cargo.lock src/lib.rs
git commit -m "Update Rust dependencies for tokenizers v1.22.1"
```

### 6. Verify in Konflux build

Create a pull request and test the changes:

1. Push your changes to a branch
2. Create a pull request
3. Comment `/build-konflux` in the PR to trigger the Konflux build
4. Verify that the `prefetch-dependencies` task completes successfully
   - The task should run `cargo vendor --locked --versioned-dirs --no-delete`
   - All Rust dependencies should be vendored without errors
   - The build should proceed to the next steps

### 7. Update Dockerfile.konflux if needed

If you're changing the tokenizers version, also update the source tarball reference in `Dockerfile.konflux`:

```dockerfile
tar -xzf /cachi2/output/deps/generic/tokenizers-v1.22.1.tar.gz --strip-components=1
```

And update the corresponding entry in `artifacts.lock.yaml` or `generic_lockfile.yaml`:

```yaml
- filename: "tokenizers-v1.22.1.tar.gz"
  download_url: "https://github.com/daulet/tokenizers/archive/refs/tags/v1.22.1.tar.gz"
  checksum: sha256:<checksum>
```

## Current Version

- **Tokenizers version**: v1.22.1
- **Cargo.toml source**: https://github.com/daulet/tokenizers/blob/v1.22.1/Cargo.toml
- **Cargo.lock source**: https://github.com/daulet/tokenizers/blob/v1.22.1/Cargo.lock

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

- `Cargo.toml` - Rust package manifest
- `Cargo.lock` - Locked dependency versions
- `src/lib.rs` - Minimal library file required by Cargo.toml
- `Dockerfile.konflux` - Build file that uses vendored dependencies
- `artifacts.lock.yaml` / `generic_lockfile.yaml` - Lockfiles for tokenizers source tarball
