//! The cli entrypoint for the `splice` subcommand

use std::env;
use std::fs;
use std::path::PathBuf;

use anyhow::Context;
use clap::Parser;

use crate::cli::Result;
use crate::metadata::{write_metadata, Generator, MetadataGenerator};
use crate::splicing::{generate_lockfile, Splicer, SplicingManifest, WorkspaceMetadata};

/// Command line options for the `splice` subcommand
#[derive(Parser, Debug)]
#[clap(about, version)]
pub struct SpliceOptions {
    /// The path to a Cargo binary to use for gathering metadata
    #[clap(long, env = "CARGO")]
    pub cargo: PathBuf,

    /// The path to a rustc binary for use with Cargo
    #[clap(long, env = "RUSTC")]
    pub rustc: PathBuf,

    /// A generated manifest of splicing inputs
    #[clap(long)]
    pub splicing_manifest: PathBuf,

    /// A Cargo lockfile (Cargo.lock).
    #[clap(long)]
    pub cargo_lockfile: Option<PathBuf>,

    /// The directory in which to build the workspace. If this argument is not
    /// passed, a temporary directory will be generated.
    #[clap(long)]
    pub workspace_dir: Option<PathBuf>,

    /// The location where the results of splicing are written.
    #[clap(long)]
    pub output_dir: PathBuf,

    /// If true, outputs will be printed instead of written to disk.
    #[clap(long)]
    pub dry_run: bool,

    /// The path to a Cargo configuration file.
    #[clap(long)]
    pub cargo_config: Option<PathBuf>,

    /// The output path for the Cargo lockfile.
    #[clap(long)]
    pub out_cargo_lockfile: PathBuf,

    /// The output path for the metadata.
    #[clap(long)]
    pub out_metadata: PathBuf,
}

impl SpliceOptions {
    // Canonicalize all option paths.
    fn canonicalize(self: Self) -> Result<Self> {
        Ok(Self {
            cargo: fs::canonicalize(self.cargo)?,
            rustc: fs::canonicalize(self.rustc)?,
            splicing_manifest: fs::canonicalize(self.splicing_manifest)?,
            cargo_lockfile: try_canonicalize(self.cargo_lockfile)?,
            workspace_dir: try_canonicalize(self.workspace_dir)?,
            output_dir: fs::canonicalize(self.output_dir)?,
            cargo_config: try_canonicalize(self.cargo_config)?,
            // Cannot canonicalize paths which don't exist.
            // out_cargo_lockfile: fs::canonicalize(self.out_cargo_lockfile)?,
            // out_metadata: fs::canonicalize(self.out_metadata)?,
            ..self
        })
    }
}

// Canonicalize the path if some.
fn try_canonicalize(path: Option<PathBuf>) -> Result<Option<PathBuf>> {
    Ok(path.and_then(|x| Some(fs::canonicalize(x))).transpose()?)
}

/// Combine a set of disjoint manifests into a single workspace.
pub fn splice(opt: SpliceOptions) -> Result<()> {
    let opt = opt.canonicalize()?;

    // Required for the cargo-metadata crate as there's no way to explicitly
    // provide the rustc path.
    env::set_var("CARGO", &opt.cargo);
    env::set_var("RUSTC", &opt.rustc);

    // Load the all config files required for splicing a workspace
    let splicing_manifest = SplicingManifest::try_from_path(&opt.splicing_manifest)?;

    // Determine the splicing workspace
    let temp_dir;
    let splicing_dir = match &opt.workspace_dir {
        Some(dir) => dir.clone(),
        None => {
            temp_dir = tempfile::tempdir().context("Failed to generate temporary directory")?;
            temp_dir.as_ref().to_path_buf()
        }
    };

    // Generate a splicer for creating a Cargo workspace manifest
    let splicer = Splicer::new(splicing_dir, splicing_manifest)?;

    // Splice together the manifest
    let manifest_path = splicer.splice_workspace()?;

    // Generate a lockfile
    let cargo_lockfile =
        generate_lockfile(&manifest_path, &opt.cargo_lockfile, &opt.cargo, &opt.rustc)?;

    // Write the registry url info to the manifest now that a lockfile has been generated
    WorkspaceMetadata::write_registry_urls(&cargo_lockfile, &manifest_path)?;

    let output_dir = opt.output_dir.clone();

    // Write metadata to the workspace for future reuse
    let (cargo_metadata, _) = Generator::new()
        .with_cargo(opt.cargo)
        .with_rustc(opt.rustc)
        .generate(&manifest_path.as_path_buf())?;

    let cargo_lockfile_path = manifest_path
        .as_path_buf()
        .parent()
        .with_context(|| {
            format!(
                "The path {} is expected to have a parent directory",
                manifest_path.as_path_buf().display()
            )
        })?
        .join("Cargo.lock");

    // Generate the consumable outputs of the splicing process
    std::fs::create_dir_all(&output_dir)
        .with_context(|| format!("Failed to create directories for {}", &output_dir.display()))?;

    write_metadata(&opt.out_metadata, &cargo_metadata)?;

    std::fs::copy(cargo_lockfile_path, opt.out_cargo_lockfile)
        .context("Failed to copy lockfile")?;

    Ok(())
}
