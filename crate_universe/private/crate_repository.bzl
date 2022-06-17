load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//crate_universe/private:format.bzl", "format_build_file_name", "format_crate_repository_name")

def crate_repositories(crate_index, manifest):
    for crate in manifest.get("crates", {}).values():
        crate_repository(crate_index, crate)

def crate_repository(crate_index, crate):
    repo = crate.get("repository")
    if not repo:
        return

    crate_index_label = Label(crate_index)

    name = format_crate_repository_name(
        crate_index_label.workspace_name,
        crate.get("name"),
        crate.get("version"),
    )

    build_file = crate_index_label.relative(format_build_file_name(crate.get("name"), crate.get("version")))

    def declare_crate_repository_http_archive():
        v = repo.get("Http")
        if not v:
            return
        maybe(
            http_archive,
            name = name,
            build_file = build_file,
            patch_args = v.get("patch_args"),
            patch_tool = v.get("patch_tool"),
            patches = v.get("patches"),
            sha256 = v.get("sha256"),
            shallow_since = v.get("shallow_since"),
            strip_prefix = "{}-{}".format(crate.get("name"), crate.get("version")),
            # TODO: Maybe allow other kinds of archive?
            type = "tar.gz",
            urls = [v.get("url")],
        )

    def declare_crate_repository_git():
        v = repo.get("Git")
        if not v:
            return
        commitish = v.get("commitish", {})
        maybe(
            new_git_repository,
            name = name,
            branch = commitish.get("Branch"),
            build_file = build_file,
            commit = commitish.get("Rev"),
            init_submodules = True,
            patch_args = v.get("patch_args"),
            patch_tool = v.get("patch_tool"),
            patches = v.get("patches"),
            remote = v.get("remote"),
            shallow_since = v.get("shallow_since"),
            strip_prefix = v.get("strip_prefix"),
            tag = commitish.get("Tag"),
        )

    declare_crate_repository_http_archive()
    declare_crate_repository_git()
