//! The cli entrypoint for the `generate` subcommand

use std::env;
use std::fs;
use std::path::PathBuf;

use anyhow::{bail, Result};
use clap::Parser;

use crate::config::Config;
use crate::context::Context;
use crate::lockfile::{is_cargo_lockfile, lock_context, write_lockfile, LockfileKind};
use crate::metadata::load_metadata;
use crate::metadata::Annotations;
use crate::splicing::SplicingManifest;

/// Command line options for the `generate` subcommand
#[derive(Parser, Debug)]
#[clap(about, version)]
pub struct GenerateOptions {
    /// The path to a Cargo binary to use for gathering metadata
    #[clap(long, env = "CARGO")]
    pub cargo: Option<PathBuf>,

    /// The path to a rustc binary for use with Cargo
    #[clap(long, env = "RUSTC")]
    pub rustc: Option<PathBuf>,

    /// The config file with information about the Bazel and Cargo workspace
    #[clap(long)]
    pub config: PathBuf,

    /// A generated manifest of splicing inputs
    #[clap(long)]
    pub splicing_manifest: PathBuf,

    /// The path to either a Cargo or Bazel lockfile
    #[clap(long)]
    pub lockfile: PathBuf,

    /// The type of lockfile
    #[clap(long)]
    pub lockfile_kind: LockfileKind,

    /// A [Cargo config](https://doc.rust-lang.org/cargo/reference/config.html#configuration)
    /// file to use when gathering metadata
    #[clap(long)]
    pub cargo_config: Option<PathBuf>,

    /// The path to a Cargo metadata `json` file.
    #[clap(long)]
    pub metadata: Option<PathBuf>,

    /// If true, outputs will be printed instead of written to disk.
    #[clap(long)]
    pub dry_run: bool,

    /// The output path for the Cargo Bazel lockfile.
    #[clap(long)]
    pub out_lockfile: PathBuf,
}

impl GenerateOptions {
    // Canonicalize all option paths.
    fn canonicalize(self: Self) -> Result<Self> {
        Ok(Self {
            cargo: try_canonicalize(self.cargo)?,
            rustc: try_canonicalize(self.rustc)?,
            config: fs::canonicalize(self.config)?,
            splicing_manifest: fs::canonicalize(self.splicing_manifest)?,
            lockfile: fs::canonicalize(self.lockfile)?,
            cargo_config: try_canonicalize(self.cargo_config)?,
            metadata: try_canonicalize(self.metadata)?,
            ..self
        })
    }
}

// Canonicalize the path if some.
fn try_canonicalize(path: Option<PathBuf>) -> Result<Option<PathBuf>> {
    Ok(path.and_then(|x| Some(fs::canonicalize(x))).transpose()?)
}

pub fn generate(opt: GenerateOptions) -> Result<()> {
    let opt = opt.canonicalize()?;

    // Load the config
    let config = Config::try_from_path(&opt.config)?;

    // Ensure Cargo and Rustc are available for use during generation.
    let cargo_bin = match &opt.cargo {
        Some(bin) => bin,
        None => bail!("The `--cargo` argument is required when generating unpinned content"),
    };
    let rustc_bin = match &opt.rustc {
        Some(bin) => bin,
        None => bail!("The `--rustc` argument is required when generating unpinned content"),
    };

    // Ensure a path to a metadata file was provided
    let metadata_path = match &opt.metadata {
        Some(path) => path,
        None => bail!("The `--metadata` argument is required when generating unpinned content"),
    };

    // Required for the cargo-metadata crate as there's no way to explicitly
    // provide the rustc path.
    env::set_var("CARGO", &cargo_bin);
    env::set_var("RUSTC", &rustc_bin);

    // Load Metadata and Lockfile
    let (cargo_metadata, cargo_lockfile) = load_metadata(
        metadata_path,
        // TODO: Unconditionally provide the lockfile.
        if is_cargo_lockfile(&opt.lockfile, &opt.lockfile_kind) {
            Some(&opt.lockfile)
        } else {
            None
        },
    )?;

    // Annotate metadata.
    let annotations = Annotations::new(cargo_metadata, cargo_lockfile, config.clone())?;

    // Generate renderable contexts for each package.
    let context = Context::new(annotations)?;

    let splicing_manifest = SplicingManifest::try_from_path(&opt.splicing_manifest)?;

    let lockfile = lock_context(context, &config, &splicing_manifest, cargo_bin, rustc_bin)?;

    write_lockfile(lockfile, &opt.out_lockfile, opt.dry_run)?;

    Ok(())
}
