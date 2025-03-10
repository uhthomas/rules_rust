"""A custom rule that threats all its dependencies as direct dependencies."""

# buildifier: disable=bzl-visibility
load("//rust/private:common.bzl", "rust_common")

# buildifier: disable=bzl-visibility
load("//rust/private:providers.bzl", "BuildInfo", "CrateInfo", "DepInfo", "DepVariantInfo")

# buildifier: disable=bzl-visibility
load("//rust/private:rustc.bzl", "rustc_compile_action")

def _generator_impl(ctx):
    rs_file = ctx.actions.declare_file(ctx.label.name + "_generated.rs")
    ctx.actions.run_shell(
        outputs = [rs_file],
        command = """cat <<EOF > {}
use direct::direct_fn;
use transitive::transitive_fn;

pub fn call_both() {}
    direct_fn();
    transitive_fn();
{}
EOF
""".format(rs_file.path, "{", "}"),
        mnemonic = "WriteRsFile",
    )

    toolchain = ctx.toolchains[Label("//rust:toolchain")]

    # Determine unique hash for this rlib
    output_hash = repr(hash(rs_file.path))
    crate_name = ctx.label.name
    crate_type = "rlib"

    rust_lib_name = "{prefix}{name}-{lib_hash}{extension}".format(
        prefix = "lib",
        name = crate_name,
        lib_hash = output_hash,
        extension = ".rlib",
    )

    deps = [DepVariantInfo(
        crate_info = dep[CrateInfo] if CrateInfo in dep else None,
        dep_info = dep[DepInfo] if DepInfo in dep else None,
        build_info = dep[BuildInfo] if BuildInfo in dep else None,
        cc_info = dep[CcInfo] if CcInfo in dep else None,
    ) for dep in ctx.attr.deps]

    rust_lib = ctx.actions.declare_file(rust_lib_name)
    return rustc_compile_action(
        ctx = ctx,
        attr = ctx.attr,
        toolchain = toolchain,
        crate_info = rust_common.create_crate_info(
            name = crate_name,
            type = crate_type,
            root = rs_file,
            srcs = depset([rs_file]),
            deps = depset(deps),
            proc_macro_deps = depset([]),
            aliases = {},
            output = rust_lib,
            owner = ctx.label,
            edition = "2018",
            compile_data = depset([]),
            rustc_env = {},
            is_test = False,
        ),
        output_hash = output_hash,
        force_all_deps_direct = True,
    )

generator = rule(
    implementation = _generator_impl,
    attrs = {
        "deps": attr.label_list(),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_error_format": attr.label(
            default = Label("//:error_format"),
        ),
        "_process_wrapper": attr.label(
            default = Label("//util/process_wrapper"),
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    toolchains = ["@rules_rust//rust:toolchain", "@bazel_tools//tools/cpp:toolchain_type"],
    incompatible_use_toolchain_transition = True,
    fragments = ["cpp"],
)
