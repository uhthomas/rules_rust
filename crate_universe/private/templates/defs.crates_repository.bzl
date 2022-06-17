# TODO: The "rules_rust" part needs to be templated.
load(
    "@rules_rust//crate_universe/private:crate_index.bzl",
    _aliases = "aliases",
    _all_crate_deps = "all_crate_deps",
    _crate_deps = "crate_deps",
)
load("@rules_rust//crate_universe/private:crate_repository.bzl", _crate_repositories = "crate_repositories")
load("//:manifest.bzl", "CRATE_INDEX", "MANIFEST")

def crate_repositories():
    _crate_repositories(CRATE_INDEX, MANIFEST)

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    return _aliases(
        CRATE_INDEX,
        MANIFEST,
        normal,
        normal_dev,
        proc_macro,
        proc_macro_dev,
        build,
        build_proc_macro,
        package_name,
    )

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    return _all_crate_deps(
        CRATE_INDEX,
        MANIFEST,
        normal,
        normal_dev,
        proc_macro,
        proc_macro_dev,
        build,
        build_proc_macro,
        package_name,
    )

def crate_deps(deps, package_name = None):
    return _crate_deps(CRATE_INDEX, MANIFEST, deps, package_name)
