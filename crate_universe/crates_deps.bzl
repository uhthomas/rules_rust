"""Transitive dependencies of the `cargo-bazel` Rust target"""

load("@crate_universe_crate_index//:defs.bzl", _repository_crate_repositories = "crate_repositories")

def crate_repositories():
    _repository_crate_repositories()
