"""A generate file containing all source files used to produce `cargo-bazel`"""

# Each source file is tracked as a target so the `cargo_bootstrap_repository`
# rule will know to automatically rebuild if any of the sources changed.
CARGO_BAZEL_SRCS = [
    "@rules_rust//crate_universe:src/cli.rs",
    "@rules_rust//crate_universe:src/cli/generate.rs",
    "@rules_rust//crate_universe:src/cli/query.rs",
    "@rules_rust//crate_universe:src/cli/splice.rs",
    "@rules_rust//crate_universe:src/config.rs",
    "@rules_rust//crate_universe:src/context.rs",
    "@rules_rust//crate_universe:src/context/crate_context.rs",
    "@rules_rust//crate_universe:src/context/platforms.rs",
    "@rules_rust//crate_universe:src/lib.rs",
    "@rules_rust//crate_universe:src/lockfile.rs",
    "@rules_rust//crate_universe:src/main.rs",
    "@rules_rust//crate_universe:src/metadata.rs",
    "@rules_rust//crate_universe:src/metadata/dependency.rs",
    "@rules_rust//crate_universe:src/metadata/metadata_annotation.rs",
    "@rules_rust//crate_universe:src/splicing.rs",
    "@rules_rust//crate_universe:src/splicing/cargo_config.rs",
    "@rules_rust//crate_universe:src/splicing/splicer.rs",
    "@rules_rust//crate_universe:src/test.rs",
    "@rules_rust//crate_universe:src/utils.rs",
    "@rules_rust//crate_universe:src/utils/starlark.rs",
    "@rules_rust//crate_universe:src/utils/starlark/glob.rs",
    "@rules_rust//crate_universe:src/utils/starlark/label.rs",
    "@rules_rust//crate_universe:src/utils/starlark/select.rs",
]
