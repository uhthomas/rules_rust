load(
    "//crate_universe/private:crate_targets.bzl",
    "make_aliases",
    "make_context",
    "make_selectable_deps",
)
load("//crate_universe/private:format.bzl", "format_crate_label_name")

# TODO: RENAME?
def workspace_members(crate_index, manifest):
    crates = manifest.get("crates", {})

    deps = {}
    for (name, path) in manifest.get("workspace_members", {}).items():
        (_crate, common, selects) = _all_crate_deps(
            manifest = manifest,
            normal = True,
            normal_dev = True,
            proc_macro = True,
            proc_macro_dev = True,
            build = True,
            build_proc_macro = True,
            package_name = path,
        )

        for dep in common + [dep for items in selects.items() for dep in items]:
            deps.setdefault(
                dep.get("alias", crates.get(dep.get("id")).get("name")),
                {},
            ).update({dep.get("id"): dep})

    for (name, _deps) in deps.items():
        for (id, dep) in _deps.items():
            crate = crates.get(id)
            native.alias(
                name = name if len(_deps) == 1 else "{}-{}".format(
                    name,
                    id,
                ),
                actual = format_crate_label_name(
                    Label(crate_index).workspace_name,
                    crate.get("name"),
                    crate.get("version"),
                    crate.get("library_target_name"),
                ),
                visibility = ["//visibility:public"],
            )

    binaries = {}
    for id in manifest.get("binary_crates", []):
        crate = crates.get(id)
        binaries.setdefault(crate.get("name"), []).append(crate)

    for _crates in binaries.values():
        for crate in _crates:
            for target in crate.get("targets", []):
                v = target.get("Binary")
                if not v:
                    continue
                native.alias(
                    name = "{}__{}".format(
                        crate.get("name") if len(_crates) == 1 else "{}-{}".format(
                            crate.get("name"),
                            crate.get("version"),
                        ),
                        v.get("crate_name"),
                    ),
                    actual = format_crate_label_name(
                        Label(crate_index).workspace_name,
                        crate.get("name"),
                        crate.get("version"),
                        "{}__bin".format(v.get("crate_name")),
                    ),
                    visibility = ["//visibility:public"],
                )

def aliases(
        crate_index,
        manifest,
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    crate = _get_crate(manifest, package_name or native.package_name())
    if not crate:
        return {}

    # TODO: This is wrong
    return make_aliases(make_context(crate_index, manifest, crate, None))

def all_crate_deps(
        crate_index,
        manifest,
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    (crate, common, selects) = _all_crate_deps(
        manifest,
        normal,
        normal_dev,
        proc_macro,
        proc_macro_dev,
        build,
        build_proc_macro,
        package_name,
    )
    if not crate:
        return []
    ctx = make_context(crate_index, manifest, crate, None)
    return make_selectable_deps(ctx, {
        "common": common,
        "selects": selects,
    })

def _all_crate_deps(
        manifest,
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    normal = normal or not any([
        normal,
        normal_dev,
        proc_macro,
        proc_macro_dev,
        build,
        build_proc_macro,
    ])

    crate = _get_crate(manifest, package_name or native.package_name())
    if not crate:
        return (None, None, None)

    common_attrs = crate.get("common_attrs", {})

    common = []
    selects = {}

    def extend(deps):
        if not deps:
            return
        common.extend(deps.get("common", []))
        for (k, v) in deps.get("selects", {}).items():
            selects.setdefault(k, []).extend(v)

    if normal:
        extend(common_attrs.get("deps"))
    if normal_dev:
        extend(common_attrs.get("deps_dev"))
    if proc_macro:
        extend(common_attrs.get("proc_macro_deps"))
    if proc_macro_dev:
        extend(common_attrs.get("proc_macro_deps_dev"))

    build_script_attrs = crate.get("build_script_attrs", {})
    if build:
        extend(build_script_attrs.get("deps"))
    if build_proc_macro:
        extend(build_script_attrs.get("proc_macro_deps"))

    return (crate, common, selects)

def crate_deps(crate_index, manifest, deps, package_name = None):
    crate = _get_crate(manifest, package_name)
    if not crate:
        return []
    return []

def _get_crate(manifest, package_name):
    crates = manifest.get("crates", {})
    for (name, path) in manifest.get("workspace_members", {}).items():
        if path == package_name:
            return crates.get(name)
    return None
