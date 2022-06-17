"""A module defining dependencies of the `cargo-bazel` Rust target"""

load("@rules_rust//rust:defs.bzl", "rust_common")
load("//crate_universe/3rdparty:third_party_deps.bzl", "third_party_deps")
load("//crate_universe/private:crate.bzl", "crate")
load("//crate_universe/private:crates_repository.bzl", "crates_repository")
load("//crate_universe/tools/cross_installer:cross_installer_deps.bzl", "cross_installer_deps")

_REPOSITORY_NAME = "crate_universe_crate_index"

_ANNOTATIONS = {
    "libgit2-sys": [crate.annotation(
        gen_build_script = False,
        deps = ["@libgit2"],
    )],
    "libz-sys": [crate.annotation(
        gen_build_script = False,
        deps = ["@zlib"],
    )],
}

_MANIFESTS = [
    "@rules_rust//crate_universe:Cargo.toml",
    "@rules_rust//crate_universe/tools/cross_installer:Cargo.toml",
    "@rules_rust//crate_universe/tools/copy_file:Cargo.toml",
]

def crate_universe_dependencies(rust_version = rust_common.default_version, bootstrap = False):
    """Define dependencies of the `cargo-bazel` Rust target

    Args:
        rust_version (str, optional): The version of rust to use when generating dependencies.
        bootstrap (bool, optional): If true, a `cargo_bootstrap_repository` target will be generated.
    """
    third_party_deps()

    crates_repository(
        name = _REPOSITORY_NAME,
        annotations = _ANNOTATIONS,
        # generator = "@cargo_bazel_bootstrap//:cargo-bazel" if bootstrap else None,
        lockfile = "@rules_rust//crate_universe:Cargo.Bazel.lock",
        manifests = _MANIFESTS,
        rust_version = rust_version,
    )

    cross_installer_deps()
