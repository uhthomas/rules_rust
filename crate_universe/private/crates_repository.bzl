"""`crates_repository` rule implementation"""

load("//crate_universe/private:format.bzl", "format_build_file_name")
load("//crate_universe/private:generate_utils.bzl", "CRATES_REPOSITORY_ENVIRON", "generate_config", "get_lockfile")
load("//crate_universe/private:splicing_utils.bzl", "create_splicing_manifest")
load("//rust:defs.bzl", "rust_common")
load("//rust/platform:triple_mappings.bzl", "SUPPORTED_PLATFORM_TRIPLES")

def read_manifest(ctx):
    content = ctx.read(ctx.attr.lockfile)
    if not content:
        return {}
    return json.decode(content)

def _crates_repository_impl(ctx):
    config = generate_config(ctx)

    # TODO: Maybe do this with build rules?
    splicing_manifest = create_splicing_manifest(ctx)

    lockfile = get_lockfile(ctx)

    if lockfile.kind != "bazel":
        # TODO: How should a cargo.toml be handled? Probably not at all?
        fail("unsupported lockfile kind")

    manifest = read_manifest(ctx)

    # TODO: Maybe it's not necessary to generate a whole build file per crate?
    # It could just be one build file with a macro.
    for (crate_name, crate) in manifest.get("crates", {}).items():
        ctx.template(
            format_build_file_name(
                crate.get("name"),
                crate.get("version"),
            ),
            ctx.attr._crate_build_template,
            substitutions = {
                "{crate_index}": ctx.name,
                "{crate_name}": crate_name,
                "{additive_build_file_content}": "\n" + crate.get("additive_build_file_content", ""),
            },
            executable = False,
        )

    ctx.template(
        "manifest.bzl",
        ctx.attr._manifest_template,
        substitutions = {
            "{crate_index}": ctx.name,
            "{config}": config,
            "{lockfile_path}": str(lockfile.path),
            "{manifest}": repr(manifest),
            "{splicing_manifest}": splicing_manifest,
        },
        executable = False,
    )

    ctx.symlink(ctx.attr._build_template, "BUILD.bazel")
    ctx.symlink(ctx.attr._defs_template, "defs.bzl")

crates_repository = repository_rule(
    doc = """\
A rule for defining and downloading Rust dependencies (crates). This rule
handles all the same [workflows](#workflows) `crate_universe` rules do.

Environment Variables:

| variable | usage |
| --- | --- |
| `CARGO_BAZEL_GENERATOR_SHA256` | The sha256 checksum of the file located at `CARGO_BAZEL_GENERATOR_URL` |
| `CARGO_BAZEL_GENERATOR_URL` | The URL of a cargo-bazel binary. This variable takes precedence over attributes and can use `file://` for local paths |
| `CARGO_BAZEL_ISOLATED` | An authorative flag as to whether or not the `CARGO_HOME` environment variable should be isolated from the host configuration |
| `CARGO_BAZEL_REPIN` | An indicator that the dependencies represented by the rule should be regenerated. `REPIN` may also be used. |

Example:

Given the following workspace structure:
```
[workspace]/
    WORKSPACE
    BUILD
    Cargo.toml
    Cargo.Bazel.lock
    src/
        main.rs
```

The following is something that'd be found in the `WORKSPACE` file:

```python
load("@rules_rust//crate_universe:defs.bzl", "crates_repository", "crate")

crates_repository(
    name = "crate_index",
    annotations = annotations = {
        "rand": [crate.annotation(
            default_features = False,
            features = ["small_rng"],
        )],
    },
    lockfile = "//:Cargo.Bazel.lock",
    manifests = ["//:Cargo.toml"],
    # Should match the version represented by the currently registered `rust_toolchain`.
    rust_version = "1.60.0",
)
```

The above will create an external repository which contains aliases and macros for accessing
Rust targets found in the dependency graph defined by the given manifests.

**NOTE**: The `lockfile` must be manually created. The rule unfortunately does not yet create
it on its own. When initially setting up this rule, an empty file should be created and then
populated by repinning dependencies.

### Repinning / Updating Dependencies

Dependency syncing and updating is done in the repository rule which means it's done during the
analysis phase of builds. As mentioned in the environments variable table above, the `CARGO_BAZEL_REPIN`
(or `REPIN`) environment variables can be used to force the rule to update dependencies and potentially
render a new lockfile. Given an instance of this repository rule named `crate_index`, the easiest way to
repin dependencies is to run:

```shell
CARGO_BAZEL_REPIN=1 bazel sync --only=crate_index
```

""",
    implementation = _crates_repository_impl,
    attrs = {
        "annotations": attr.string_list_dict(
            doc = "Extra settings to apply to crates. See [crate.annotation](#crateannotation).",
        ),
        "cargo_config": attr.label(
            doc = "A [Cargo configuration](https://doc.rust-lang.org/cargo/reference/config.html) file",
        ),
        "generate_build_scripts": attr.bool(
            doc = (
                "Whether or not to generate " +
                "[cargo build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html) by default."
            ),
            default = True,
        ),
        "generator": attr.string(
            doc = (
                "The absolute label of a generator. Eg. `@cargo_bazel_bootstrap//:cargo-bazel`. " +
                "This is typically used when bootstrapping"
            ),
        ),
        "isolated": attr.bool(
            doc = (
                "If true, `CARGO_HOME` will be overwritten to a directory within the generated repository in " +
                "order to prevent other uses of Cargo from impacting having any effect on the generated targets " +
                "produced by this rule. For users who either have multiple `crate_repository` definitions in a " +
                "WORKSPACE or rapidly re-pin dependencies, setting this to false may improve build times. This " +
                "variable is also controled by `CARGO_BAZEL_ISOLATED` environment variable."
            ),
            default = True,
        ),
        "lockfile": attr.label(
            doc = (
                "The path to a file to use for reproducible renderings. Two kinds of lock files are supported, " +
                "Cargo (`Cargo.lock` files) and Bazel (custom files generated by this rule, naming is irrelevant). " +
                "Bazel lockfiles should be the prefered kind as they're desigend with Bazel's notions of " +
                "reporducibility in mind. Cargo lockfiles can be used in cases where it's intended to be the " +
                "source of truth, but more work will need to be done to generate BUILD files which are not " +
                "guaranteed to be determinsitic."
            ),
            mandatory = True,
        ),
        "lockfile_kind": attr.string(
            doc = (
                "Two different kinds of lockfiles are supported, the custom \"Bazel\" lockfile, which is generated " +
                "by this rule, and Cargo lockfiles (`Cargo.lock`). This attribute allows for explicitly defining " +
                "the type in cases where it may not be auto-detectable."
            ),
            values = [
                "auto",
                "bazel",
                "cargo",
            ],
            default = "auto",
        ),
        "manifests": attr.label_list(
            doc = "A list of Cargo manifests (`Cargo.toml` files).",
        ),
        "packages": attr.string_dict(
            doc = "A set of crates (packages) specifications to depend on. See [crate.spec](#crate.spec).",
        ),
        "quiet": attr.bool(
            doc = "If stdout and stderr should not be printed to the terminal.",
            default = True,
        ),
        "render_config": attr.string(
            doc = (
                "The configuration flags to use for rendering. Use `//crate_universe:defs.bzl\\%render_config` to " +
                "generate the value for this field. If unset, the defaults defined there will be used."
            ),
        ),
        "rust_toolchain_cargo_template": attr.string(
            doc = (
                "The template to use for finding the host `cargo` binary. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{arch}` (eg. 'aarch64'), `{vendor}` (eg. 'unknown'), " +
                "`{system}` (eg. 'darwin'), `{cfg}` (eg. 'exec'), and `{tool}` (eg. 'rustc.exe') will be replaced in " +
                "the string if present."
            ),
            default = "@rust_{system}_{arch}//:bin/{tool}",
        ),
        "rust_toolchain_rustc_template": attr.string(
            doc = (
                "The template to use for finding the host `rustc` binary. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{arch}` (eg. 'aarch64'), `{vendor}` (eg. 'unknown'), " +
                "`{system}` (eg. 'darwin'), `{cfg}` (eg. 'exec'), and `{tool}` (eg. 'cargo.exe') will be replaced in " +
                "the string if present."
            ),
            default = "@rust_{system}_{arch}//:bin/{tool}",
        ),
        "rust_version": attr.string(
            doc = "The version of Rust the currently registered toolchain is using. Eg. `1.56.0`, or `nightly-2021-09-08`",
            default = rust_common.default_version,
        ),
        "splicing_config": attr.string(
            doc = (
                "The configuration flags to use for splicing Cargo maniests. Use `//crate_universe:defs.bzl\\%rsplicing_config` to " +
                "generate the value for this field. If unset, the defaults defined there will be used."
            ),
        ),
        "supported_platform_triples": attr.string_list(
            doc = "A set of all platform triples to consider when generating dependencies.",
            default = SUPPORTED_PLATFORM_TRIPLES,
        ),
        "_crate_build_template": attr.label(
            allow_single_file = True,
            default = "templates/BUILD.crate.bazel",
        ),
        "_build_template": attr.label(
            allow_single_file = True,
            default = "templates/BUILD.crates_repository.bazel",
        ),
        "_defs_template": attr.label(
            allow_single_file = True,
            default = "templates/defs.crates_repository.bzl",
        ),
        "_manifest_template": attr.label(
            allow_single_file = True,
            default = "templates/manifest.crates_repository.bzl",
        ),
    },
    environ = CRATES_REPOSITORY_ENVIRON,
)
