SpliceInfo = provider("", fields = {
    "cargo_lockfile": "",
    "metadata": "",
})

def _splice_impl(ctx):
    cargo_lockfile = ctx.actions.declare_file(ctx.label.name + "_Cargo.toml")
    metadata = ctx.actions.declare_file(ctx.label.name + "_metadata.json")

    # Temporary scratch directory.
    workspace_dir = ctx.actions.declare_directory("workspace_dir")

    toolchain_info = ctx.toolchains["//rust:toolchain"]

    args = ctx.actions.args()
    args.add("splice")
    args.add("--cargo", toolchain_info.cargo)
    args.add("--rustc", toolchain_info.rustc)
    args.add("--splicing-manifest", ctx.file.splicing_manifest)
    args.add("--output-dir", metadata.dirname)
    args.add("--workspace-dir", workspace_dir.path)
    args.add("--out-cargo-lockfile", cargo_lockfile)
    args.add("--out-metadata", metadata)

    ctx.actions.run(
        executable = ctx.executable._cargo_bazel,
        # inputs = depset(
        #     [ctx.file.splicing_manifest],
        #     # TODO: Attempts to address zlib thing, maybe remove as it didn't work.
        #     # https://github.com/bazelbuild/bazel/issues/8697
        #     transitive = [ctx.attr._cargo_bazel[DefaultInfo].default_runfiles.files],
        # ),
        inputs = [ctx.file.splicing_manifest],
        outputs = [cargo_lockfile, metadata, workspace_dir],
        arguments = [args],
        tools = [
            toolchain_info.cargo,
            toolchain_info.rustc,
        ],
        mnemonic = "Splice",
        execution_requirements = {
            # TODO: Link zlib explicitly?
            "local": "requires network access, but requires-network doesn't work. Also seems to have some trouble finding zlib.",
        },
    )

    return [
        DefaultInfo(files = depset([cargo_lockfile, metadata])),
        SpliceInfo(
            cargo_lockfile = cargo_lockfile,
            metadata = metadata,
        ),
    ]

splice = rule(
    implementation = _splice_impl,
    attrs = {
        "splicing_manifest": attr.label(allow_single_file = True),
        # TODO: Should be configurable?
        "_cargo_bazel": attr.label(
            default = "//crate_universe:bin",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = ["//rust:toolchain"],
)

def _generate_impl(ctx):
    lockfile = ctx.actions.declare_file(ctx.label.name + "_Cargo.Bazel.lock")

    splice_info = ctx.attr.metadata[SpliceInfo]
    toolchain_info = ctx.toolchains["//rust:toolchain"]

    args = ctx.actions.args()
    args.add("generate")
    args.add("--cargo", toolchain_info.cargo)
    args.add("--rustc", toolchain_info.rustc)
    args.add("--config", ctx.file.config)
    args.add("--splicing-manifest", ctx.file.splicing_manifest)
    args.add("--lockfile", splice_info.cargo_lockfile)

    # TODO: Probably make this configurable?
    args.add("--lockfile-kind", "cargo")
    args.add("--metadata", splice_info.metadata)

    args.add("--out-lockfile", lockfile)

    ctx.actions.run(
        executable = ctx.executable._cargo_bazel,
        inputs = [
            ctx.file.config,
            ctx.file.splicing_manifest,
            splice_info.cargo_lockfile,
            splice_info.metadata,
        ],
        outputs = [lockfile],
        arguments = [args],
        tools = [
            toolchain_info.cargo,
            toolchain_info.rustc,
        ],
        mnemonic = "Generate",
    )

    return [DefaultInfo(files = depset([lockfile]))]

generate = rule(
    implementation = _generate_impl,
    attrs = {
        "config": attr.label(allow_single_file = True),
        "metadata": attr.label(providers = [SpliceInfo]),
        "splicing_manifest": attr.label(allow_single_file = True),
        # TODO: Should be configurable?
        "_cargo_bazel": attr.label(
            default = "//crate_universe:bin",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = ["//rust:toolchain"],
)

def _query_test_impl(ctx):
    # lockfile = ctx.actions.declare_file(ctx.label.name + "_Cargo.Bazel.lock")

    # toolchain_info = ctx.toolchains["//rust:toolchain"]

    # args = ctx.actions.args()
    # args.add("query")
    # args.add("--cargo", toolchain_info.cargo)
    # args.add("--rustc", toolchain_info.rustc)
    # args.add("--config", ctx.file.config)
    # args.add("--splicing-manifest", ctx.file.splicing_manifest)
    # args.add("--lockfile", ctx.file.lockfile)

    # ctx.actions.run(
    #     executable = ctx.executable._cargo_bazel,
    #     inputs = [
    #         ctx.file.config,
    #         ctx.file.lockfile,
    #         ctx.file.splicing_manifest,
    #     ],
    #     outputs = [],
    #     arguments = [args],
    #     tools = [
    #         toolchain_info.cargo,
    #         toolchain_info.rustc,
    #     ],
    #     mnemonic = "Query",
    # )

    # return [DefaultInfo(files = depset([lockfile]))]
    exe = ctx.actions.declare_file(ctx.label.name + ".exe")
    ctx.actions.symlink(
        output = exe,
        target_file = ctx.executable._cargo_bazel,
        is_executable = True,
    )
    return [DefaultInfo(
        executable = exe,
        runfiles = ctx
            .runfiles(files = ctx.files.data)
            .merge(ctx.attr._cargo_bazel[DefaultInfo].default_runfiles),
    )]

_query_test = rule(
    implementation = _query_test_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        # TODO: Should be configurable?
        "_cargo_bazel": attr.label(
            default = "//crate_universe:bin",
            executable = True,
            cfg = "exec",
        ),
    },
    test = True,
    toolchains = ["//rust:toolchain"],
)

def query_test(name, config, lockfile, splicing_manifest, **kwargs):
    _query_test(
        name = name,
        args = [
            "query",
            "--cargo=$(CARGO)",
            "--rustc=$(RUSTC)",
            "--config=$(rootpath {})".format(config),
            "--lockfile=$(rootpath {})".format(lockfile),
            "--splicing-manifest=$(rootpath {})".format(splicing_manifest),
        ],
        data = [config, lockfile, splicing_manifest],
        **kwargs
    )
