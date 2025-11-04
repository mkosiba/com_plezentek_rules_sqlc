load("//sqlc/private:release.bzl", "sqlc_download_release_bzlmod")
load(
    "//sqlc/private/rules_go/lib:platforms.bzl",
    "generate_toolchain_names",
)

_toolchain_tag = tag_class(
    attrs = {
        "goarch": attr.string(),
        "goos": attr.string(),
        "version": attr.string(),
        "urls": attr.string_list(default = ["https://github.com/kyleconroy/sqlc/releases/download/v{}/{}"]),
    },
)

def _sqlc_toolchain_hub_impl(ctx):
    """Implementation for the hub repository that aliases all registered toolchains."""
    repo_names = ctx.attr.repo_names
    toolchain_names = generate_toolchain_names()

    build_content = []
    for name in repo_names:
        build_content.append('load("@{name}//:toolchains.bzl", {name}_declare_toolchains = "bzlmod_declare_toolchains")'.format(name = name))

    for name in repo_names:
        build_content.append("{name}_declare_toolchains()".format(name = name))

    ctx.file("BUILD.bazel", "\n".join(build_content))

_sqlc_toolchain_hub = repository_rule(
    implementation = _sqlc_toolchain_hub_impl,
    attrs = {
        "repo_names": attr.string_list(mandatory = True),
    },
)

def _toolchain_repo_name(toolchain_tag):
    return "sqlc_release_{}_{}".format(
        toolchain_tag.goos or "host",
        toolchain_tag.goarch or "host",
    )

def _make_root_module_last(modules):
    roots = []
    other = []
    for mod in modules:
        if mod.is_root:
            roots.append(mod)
        else:
            other.append(mod)

    return other + roots

def _toolchain_impl(mctx):
    toolchain_tags = {}

    # We want to process the tags such that, in the case of conflicts, the tag definitions
    # from the root module "win".
    for mod in _make_root_module_last(mctx.modules):
        for toolchain_tag in mod.tags.toolchain:
            repo_name = _toolchain_repo_name(toolchain_tag)
            toolchain_tags[repo_name] = toolchain_tag

    for release_name, toolchain_tag in toolchain_tags.items():
        sqlc_download_release_bzlmod(
            name = release_name,
            goarch = toolchain_tag.goarch,
            goos = toolchain_tag.goos,
            version = toolchain_tag.version,
        )

    _sqlc_toolchain_hub(
        name = "sqlc_toolchains",
        repo_names = list(toolchain_tags.keys()),
    )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = ["sqlc_toolchains"],
        root_module_direct_dev_deps = [],
    )

sqlc = module_extension(
    implementation = _toolchain_impl,
    tag_classes = {
        "toolchain": _toolchain_tag,
    },
)
