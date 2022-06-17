"""Utilities directly related to the `generate` step of `cargo-bazel`."""

load(":common_utils.bzl", "CARGO_BAZEL_ISOLATED")

CRATES_REPOSITORY_ENVIRON = [
    CARGO_BAZEL_ISOLATED,
]

def render_config(
        build_file_template = "//:BUILD.{name}-{version}.bazel",
        crate_label_template = "@{repository}__{name}-{version}//:{target}",
        crate_repository_template = "{repository}__{name}-{version}",
        crates_module_template = "//:{file}",
        default_package_name = None,
        platforms_template = "@rules_rust//rust/platform:{triple}"):
    """Various settings used to configure rendered outputs

    The template parameters each support a select number of format keys. A description of each key
    can be found below where the supported keys for each template can be found in the parameter docs

    | key | definition |
    | --- | --- |
    | `name` | The name of the crate. Eg `tokio` |
    | `repository` | The rendered repository name for the crate. Directly relates to `crate_repository_template`. |
    | `triple` | A platform triple. Eg `x86_64-unknown-linux-gnu` |
    | `version` | The crate version. Eg `1.2.3` |
    | `target` | The library or binary target of the crate |
    | `file` | The basename of a file |

    Args:
        build_file_template (str, optional): The base template to use for BUILD file names. The available format keys
            are [`{name}`, {version}`].
        crate_label_template (str, optional): The base template to use for crate labels. The available format keys
            are [`{repository}`, `{name}`, `{version}`, `{target}`].
        crate_repository_template (str, optional): The base template to use for Crate label repository names. The
            available format keys are [`{repository}`, `{name}`, `{version}`].
        crates_module_template (str, optional): The pattern to use for the `defs.bzl` and `BUILD.bazel`
            file names used for the crates module. The available format keys are [`{file}`].
        default_package_name (str, optional): The default package name to use in the rendered macros. This affects the
            auto package detection of things like `all_crate_deps`.
        platforms_template (str, optional): The base template to use for platform names.
            See [platforms documentation](https://docs.bazel.build/versions/main/platforms.html). The available format
            keys are [`{triple}`].

    Returns:
        string: A json encoded struct to match the Rust `config::RenderConfig` struct
    """
    return json.encode(struct(
        build_file_template = build_file_template,
        crate_label_template = crate_label_template,
        crate_repository_template = crate_repository_template,
        crates_module_template = crates_module_template,
        default_package_name = default_package_name,
        platforms_template = platforms_template,
    ))

def _crate_id(name, version):
    """Creates a `cargo_bazel::config::CrateId`.

    Args:
        name (str): The name of the crate
        version (str): The crate's version

    Returns:
        str: A serialized representation of a CrateId
    """
    return "{} {}".format(name, version)

def collect_crate_annotations(annotations, repository_name):
    """Deserialize and sanitize crate annotations.

    Args:
        annotations (dict): A mapping of crate names to lists of serialized annotations
        repository_name (str): The name of the repository that owns the annotations

    Returns:
        dict: A mapping of `cargo_bazel::config::CrateId` to sets of annotations
    """
    annotations = {name: [json.decode(a) for a in annotation] for name, annotation in annotations.items()}
    crate_annotations = {}
    for name, annotation in annotations.items():
        for (version, data) in annotation:
            if name == "*" and version != "*":
                fail(
                    "Wildcard crate names must have wildcard crate versions. " +
                    "Please update the `annotations` attribute of the {} crates_repository".format(
                        repository_name,
                    ),
                )
            id = _crate_id(name, version)
            if id in crate_annotations:
                fail("Found duplicate entries for {}".format(id))

            crate_annotations.update({id: data})
    return crate_annotations

def _read_cargo_config(repository_ctx):
    if repository_ctx.attr.cargo_config:
        config = repository_ctx.path(repository_ctx.attr.cargo_config)
        return repository_ctx.read(config)
    return None

def _update_render_config(config, repository_name):
    """Add the repository name to the render config

    Args:
        config (dict): A `render_config` struct
        repository_name (str): The name of the repository that owns the config

    Returns:
        struct: An updated `render_config`.
    """

    # Add the repository name as it's very relevant to rendering.
    config.update({"repository_name": repository_name})

    return struct(**config)

def _get_render_config(repository_ctx):
    if repository_ctx.attr.render_config:
        config = dict(json.decode(repository_ctx.attr.render_config))
    else:
        config = dict(json.decode(render_config()))

    return config

def compile_config(crate_annotations, generate_build_scripts, cargo_config, render_config, supported_platform_triples, repository_name, repository_ctx = None):
    """Create a config file for generating crate targets

    [cargo_config]: https://doc.rust-lang.org/cargo/reference/config.html

    Args:
        crate_annotations (dict): Extra settings to apply to crates. See
            `crates_repository.annotations` or `crates_vendor.annotations`.
        generate_build_scripts (bool): Whether or not to globally disable build scripts.
        cargo_config (str): The optional contents of a [Cargo config][cargo_config].
        render_config (dict): The deserialized dict of the `render_config` function.
        supported_platform_triples (list): A list of platform triples
        repository_name (str): The name of the repository being generated
        repository_ctx (repository_ctx, optional): A repository context object used for enabling
            certain functionality.

    Returns:
        struct: A struct matching a `cargo_bazel::config::Config`.
    """
    annotations = collect_crate_annotations(crate_annotations, repository_name)

    # Load additive build files if any have been provided.
    unexpected = []
    for name, data in annotations.items():
        f = data.pop("additive_build_file", None)
        if f and not repository_ctx:
            unexpected.append(name)
            f = None
        content = [x for x in [
            data.pop("additive_build_file_content", None),
            repository_ctx.read(Label(f)) if f else None,
        ] if x]
        if content:
            data.update({"additive_build_file_content": "\n".join(content)})

    if unexpected:
        fail("The following annotations use `additive_build_file` which is not supported for {}: {}".format(repository_name, unexpected))

    config = struct(
        generate_build_scripts = generate_build_scripts,
        annotations = annotations,
        cargo_config = cargo_config,
        rendering = _update_render_config(
            config = render_config,
            repository_name = repository_name,
        ),
        supported_platform_triples = supported_platform_triples,
    )

    return config

def generate_config(repository_ctx):
    """Generate a config file from various attributes passed to the rule.

    Args:
        repository_ctx (repository_ctx): The rule's context object.

    Returns:
        struct: A struct containing the path to a config and it's contents
    """

    config = compile_config(
        crate_annotations = repository_ctx.attr.annotations,
        generate_build_scripts = repository_ctx.attr.generate_build_scripts,
        cargo_config = _read_cargo_config(repository_ctx),
        render_config = _get_render_config(repository_ctx),
        supported_platform_triples = repository_ctx.attr.supported_platform_triples,
        repository_name = repository_ctx.name,
        repository_ctx = repository_ctx,
    )

    config_path = "cargo-bazel.json"
    repository_ctx.file(
        config_path,
        json.encode_indent(config, indent = " " * 4),
    )

    return config_path

def get_lockfile(repository_ctx):
    """Locate the lockfile and identify the it's type (Cargo or Bazel).

    Args:
        repository_ctx (repository_ctx): The rule's context object.

    Returns:
        struct: The path to the lockfile as well as it's type
    """
    if repository_ctx.attr.lockfile_kind == "auto":
        if str(repository_ctx.attr.lockfile).endswith("Cargo.lock"):
            kind = "cargo"
        else:
            kind = "bazel"
    else:
        kind = repository_ctx.attr.lockfile_kind

    return struct(
        path = repository_ctx.path(repository_ctx.attr.lockfile),
        kind = kind,
    )
