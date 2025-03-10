"""Transitive dependencies of the `cargo-bazel` Rust target"""

load("@cui//:defs.bzl", _repository_crate_repositories = "crate_repositories")
load("//crate_universe:repositories.bzl", "USE_CRATES_REPOSITORY")

def crate_repositories():
    if USE_CRATES_REPOSITORY:
        _repository_crate_repositories()
