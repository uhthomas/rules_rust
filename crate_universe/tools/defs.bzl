def _copy_file_impl(ctx):
    exe = ctx.actions.declare_file(ctx.label.name + ".exe")
    ctx.actions.symlink(
        output = exe,
        target_file = ctx.executable._copy_file,
        is_executable = True,
    )
    return [DefaultInfo(
        executable = exe,
        runfiles = ctx
            .runfiles(files = ctx.files.data)
            .merge(ctx.attr._copy_file[DefaultInfo].default_runfiles),
    )]

_copy_file = rule(
    implementation = _copy_file_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "_copy_file": attr.label(
            default = "//crate_universe/tools/copy_file",
            executable = True,
            cfg = "exec",
        ),
    },
    executable = True,
)

def copy_file(name, src, dst, **kwargs):
    _copy_file(
        name = name,
        args = [
            "$(rootpath {})".format(src),
            "{}".format(dst),
        ],
        data = [src],
        **kwargs
    )
