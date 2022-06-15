"""A module which defines rules for testing TemplateVariableInfo"""

def _rust_toolchain_template_variable_info_test_impl(ctx):
    exe = ctx.actions.declare_file(ctx.label.name + ".exe")
    ctx.actions.symlink(
        output = exe,
        target_file = ctx.executable._bin,
        is_executable = True,
    )
    return [DefaultInfo(
        executable = exe,
        runfiles = ctx.attr._bin[DefaultInfo].default_runfiles,
    )]

rust_toolchain_template_variable_info_test = rule(
    implementation = _rust_toolchain_template_variable_info_test_impl,
    attrs = {
        "_bin": attr.label(
            default = "//test/rust_toolchain_template_variable_info:bin",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = ["//rust:toolchain"],
    test = True,
)
