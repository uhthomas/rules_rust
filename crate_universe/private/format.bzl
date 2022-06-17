# TODO: Does everything need to be normalised?

def format_name(name, version):
    return "{name}-{version}".format(
        name = normalise(name),
        version = normalise(version),
    )

def format_build_file_name(name, version):
    # TODO: This may need a //:
    return "BUILD.{name}-{version}.bazel".format(
        name = normalise(name),
        version = normalise(version),
    )

def format_crate_label_name(repository, name, version, target):
    return "@{repository}__{name}-{version}//:{target}".format(
        repository = normalise(repository),
        name = normalise(name),
        version = normalise(version),
        target = normalise(target),
    )

def format_crate_repository_name(repository, name, version):
    return "{repository}__{name}-{version}".format(
        repository = normalise(repository),
        name = normalise(name),
        version = normalise(version),
    )

def format_platform_name(triple):
    return "@rules_rust//rust/platform:{triple}".format(
        triple = triple,
    )

# normalise the given string to match workspace name constraints:
#   A-Z, a-z, 0-9, '-', '_' and '.'.
def normalise(s):
    return "".join([
        e if e.isalnum() or "-_.".find(e) != -1 else "-"
        for e in s.elems()
    ])
