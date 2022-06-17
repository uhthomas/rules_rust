load(
    "//cargo:defs.bzl",
    "cargo_build_script",
)
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_library",
    "rust_proc_macro",
    "rust_shared_library",
    "rust_static_library",
)
load(
    "//crate_universe/private:format.bzl",
    "format_crate_label_name",
    "format_platform_name",
)

def declare_crate_targets(crate_index, crate_name, manifest):
    crate = manifest.get("crates", {}).get(crate_name)
    for target in crate.get("targets"):
        ctx = make_context(crate_index, manifest, crate, target)

        common = common_attrs(ctx)

        declare_cargo_build_script(ctx, common)
        declare_rust_binary(ctx, common)
        declare_rust_library(ctx, common)
        declare_rust_proc_macro(ctx, common)
        declare_rust_shared_library(ctx, common)
        declare_rust_static_library(ctx, common)

def make_context(crate_index, manifest, crate, target):
    return struct(
        crate_index = Label(crate_index),
        manifest = manifest,
        crate = crate,
        target = target,
    )

# TODO: Can this be simplified? seems like we share lots of these attrs with the
# common attrs.
# https://github.com/bazelbuild/rules_rust/blob/521e649ff44e9711fe3c45b0ec1e792f7e1d361e/crate_universe/src/rendering/templates/partials/crate/build_script.j2
def declare_cargo_build_script(ctx, common):
    v = ctx.target.get("BuildScript")
    if not v:
        return
    name = "{}_build_script".format(ctx.crate.get("name"))
    attrs = ctx.crate.get("build_script_attrs", {})
    cargo_build_script(
        name = name,
        aliases = common.get("aliases"),
        build_script_env = make_selectable_dict(ctx, attrs.get("build_script_env")),
        compile_data = make_glob(attrs.get("compile_data_glob")) +
                       make_selectable_list(ctx, attrs.get("compile_data")),
        # TODO: normalise?
        crate_name = v.get("crate_name"),
        crate_root = v.get("crate_root"),
        crate_features = common.get("crate_features"),
        data = make_glob(attrs.get("data_glob")) +
               make_selectable_list(ctx, attrs.get("data")),
        deps = attrs.get("extra_deps", []) +
               make_selectable_deps(ctx, attrs.get("deps")),
        edition = common.get("edition"),
        linker_script = common.get("linker_script"),
        links = attrs.get("links"),
        proc_macro_deps = attrs.get("extra_proc_macro_deps", []) +
                          make_selectable_deps(ctx, attrs.get("proc_macro_deps")),
        rustc_env = make_selectable_dict(ctx, attrs.get("rustc_env")),
        rustc_env_files = make_selectable_list(ctx, attrs.get("rustc_env_files")),
        rustc_flags = [
            # In most cases, warnings in 3rd party crates are not interesting as
            # they're out of the control of consumers. The flag here silences
            # warnings. For more details see:
            # https://doc.rust-lang.org/rustc/lints/levels.html
            "--cap-lints=allow",
        ] + make_selectable_list(ctx, attrs.get("rustc_flags")),
        srcs = make_glob(**v.get("srcs", {})),
        tools = make_selectable_list(ctx, attrs.get("tools")),
        version = common.get("version"),
        tags = [
            "cargo-bazel",
            # "manual",
            "noclippy",
            "norustfmt",
        ] + common.get("tags", []),
        toolchains = attrs.get("toolchains"),
        visibility = ["//visibility:private"],
    )
    native.alias(
        # Because `cargo_build_script` does some invisible target name mutating
        # to determine the package and crate name for a build script, the Bazel
        # target name of any build script cannot be the Cargo canonical name of
        # `build_script_build` without losing out on having certain Cargo
        # environment variables set.
        name = v.get("crate_name"),
        actual = ":{}".format(name),
        # tags = ["manual"],
        visibility = ["//visibility:public"],
    )

# https://github.com/bazelbuild/rules_rust/blob/521e649ff44e9711fe3c45b0ec1e792f7e1d361e/crate_universe/src/rendering/templates/partials/crate/binary.j2
def declare_rust_binary(ctx, common):
    v = ctx.target.get("Binary")
    if not v:
        return
    common_attrs = ctx.crate.get("common_attrs", {})
    rust_binary(
        name = "{}__bin".format(v.get("crate_name")),
        deps = [":{}".format(ctx.crate.get("library_target_name"))] +
               common_attrs.get("extra_deps", []) +
               make_selectable_deps(ctx, common_attrs.get("deps")),
        proc_macro_deps = common_attrs.get("extra_proc_macro_deps", []) +
                          make_selectable_deps(ctx, common_attrs.get("proc_macro_deps")),
        crate_root = v.get("crate_root"),
        srcs = make_glob(**v.get("srcs", {})),
        **common
    )

# https://github.com/bazelbuild/rules_rust/blob/521e649ff44e9711fe3c45b0ec1e792f7e1d361e/crate_universe/src/rendering/templates/partials/crate/library.j2
def declare_rust_library(ctx, common):
    v = ctx.target.get("Library")
    if not v:
        return
    common_attrs = ctx.crate.get("common_attrs", {})
    rust_library(
        name = v.get("crate_name"),
        deps = common_attrs.get("extra_deps", []) +
               make_selectable_deps(ctx, common_attrs.get("deps")),
        proc_macro_deps = common_attrs.get("extra_proc_macro_deps", []) +
                          make_selectable_deps(ctx, common_attrs.get("proc_macro_deps")),
        crate_root = v.get("crate_root"),
        srcs = make_glob(**v.get("srcs", {})),
        **common
    )

def declare_rust_proc_macro(ctx, common):
    v = ctx.target.get("ProcMacro")
    if not v:
        return
    common_attrs = ctx.crate.get("common_attrs", {})
    rust_proc_macro(
        name = v.get("crate_name"),
        deps = common_attrs.get("extra_deps", []) +
               make_selectable_deps(ctx, common_attrs.get("deps")),
        proc_macro_deps = common_attrs.get("extra_proc_macro_deps", []) +
                          make_selectable_deps(ctx, common_attrs.get("proc_macro_deps")),
        crate_root = v.get("crate_root"),
        srcs = make_glob(**v.get("srcs", {})),
        **common
    )

def declare_rust_shared_library(ctx, common):
    v = ctx.target.get("SharedLibrary")
    if not v:
        return
    common_attrs = ctx.crate.get("common_attrs", {})
    rust_shared_library(
        name = "{}_shared".format(v.get("crate_name")),
        deps = common_attrs.get("extra_deps", []) +
               make_selectable_deps(ctx, common_attrs.get("deps")),
        proc_macro_deps = common_attrs.get("extra_proc_macro_deps", []) +
                          make_selectable_deps(ctx, common_attrs.get("proc_macro_deps")),
        crate_root = v.get("crate_root"),
        srcs = make_glob(**v.get("srcs", {})),
        **common
    )

def declare_rust_static_library(ctx, common):
    v = ctx.target.get("StaticLibrary")
    if not v:
        return
    common_attrs = ctx.crate.get("common_attrs", {})
    rust_static_library(
        name = "{}_static".format(v.get("crate_name")),
        deps = common_attrs.get("extra_deps", []) +
               make_selectable_deps(ctx, common_attrs.get("deps")),
        proc_macro_deps = common_attrs.get("extra_proc_macro_deps", []) +
                          make_selectable_deps(ctx, common_attrs.get("proc_macro_deps")),
        crate_root = v.get("crate_root"),
        srcs = make_glob(**v.get("srcs", {})),
        **common
    )

# https://github.com/bazelbuild/rules_rust/blob/521e649ff44e9711fe3c45b0ec1e792f7e1d361e/crate_universe/src/rendering/templates/partials/crate/common_attrs.j2
def common_attrs(ctx):
    v = ctx.crate.get("common_attrs")
    if not v:
        return {}
    return {
        "aliases": make_aliases(ctx),
        "compile_data": make_glob(v.get("compile_data_glob")) +
                        make_selectable_list(ctx, v.get("compile_data")),
        "crate_features": v.get("crate_features"),
        "data": make_glob(v.get("data_glob")) +
                make_selectable_list(ctx, v.get("data")),
        "edition": v.get("edition"),
        "linker_script": v.get("linker_script"),
        "rustc_env": make_selectable_dict(ctx, v.get("rustc_env")),
        "rustc_env_files": make_selectable_list(ctx, v.get("rustc_env_files")),
        "rustc_flags": [
            # In most cases, warnings in 3rd party crates are not interesting as
            # they're out of the control of consumers. The flag here silences
            # warnings. For more details see:
            # https://doc.rust-lang.org/rustc/lints/levels.html
            "--cap-lints=allow",
        ] + v.get("rustc_flags", []),
        "version": v.get("version"),
        "tags": [
            "cargo-bazel",
            # "manual",
            "noclippy",
            "norustfmt",
        ] + v.get("tags", []),
        "visibility": ["//visibility:public"],
    }

def make_glob(include = None, exclude = []):
    if not include:
        return []
    return native.glob(
        include = include,
        # exclude = [
        #     ".tmp_git_root/**",
        # ] + (exclude or []),
        exclude = exclude or [],
    )

def make_selectable_dict(ctx, selectable, f = None):
    if not selectable:
        return {}
    common = selectable.get("common", {}).items()
    d = dict({
        "//conditions:default": {},
    }, **make_selectable_dict_value(ctx, selectable.get("selects", {}), f))
    return select({
        k: dict(
            common,
            **v
        )
        for (k, v) in d.items()
    })

def make_selectable_dict_value(ctx, selectable, f = None):
    if not selectable:
        return {}
    return {
        format_platform_name(triple): f(v) if f else v
        for (cfg, v) in selectable.items()
        for triple in ctx.manifest.get("conditions").get(cfg)
    }

def make_selectable_list(ctx, selectable, f = None):
    if not selectable:
        return []
    common = selectable.get("common", [])
    common = f(common) if f else common
    return common + select(dict({
        "//conditions:default": [],
    }, **make_selectable_list_value(
        ctx,
        selectable.get("selects", {}),
        lambda items: [
            item
            for item in (f(items) if f else items)
            if not item in common
        ],
    )))

def make_selectable_list_value(ctx, selectable, f = None):
    if not selectable:
        return {}
    d = {}
    for (k, v) in [
        (format_platform_name(triple), f(v) if f else v)
        for (cfg, v) in selectable.items()
        for triple in ctx.manifest.get("conditions").get(cfg)
    ]:
        d.setdefault(k, []).extend(v)
    return d

def make_selectable_deps(ctx, selectable):
    return make_selectable_list(ctx, selectable, lambda deps: make_deps(ctx, deps))

def make_deps(ctx, deps):
    if not deps:
        return []
    return [make_dep(ctx, dep) for dep in deps]

def make_dep(ctx, dep):
    v = ctx.manifest.get("crates", {}).get(dep.get("id"))
    return format_crate_label_name(
        ctx.crate_index.workspace_name,
        v.get("name"),
        v.get("version"),
        dep.get("target"),
    )

def make_aliases(ctx):
    f = (lambda deps: {
        _format_crate_label_name(ctx, dep): alias
        for (dep, alias) in [(dep, dep.get("alias")) for dep in deps]
        if alias
    })

    common_attrs = ctx.crate.get("common_attrs", {})

    deps = common_attrs.get("deps", {})
    proc_macro_deps = common_attrs.get("proc_macro_deps", {})

    return make_selectable_dict(ctx, {
        "common": dict(f(deps.get("common", [])).items() + f(proc_macro_deps.get("common", [])).items()),
        "selects": dict(deps.get("selects", {}).items() + proc_macro_deps.get("selects", {}).items()),
    }, f)

def _format_crate_label_name(ctx, dep):
    crate = ctx.manifest.get("crates", {}).get(dep.get("id"))
    return format_crate_label_name(
        ctx.crate_index.workspace_name,
        crate.get("name"),
        crate.get("version"),
        dep.get("target"),
    )
