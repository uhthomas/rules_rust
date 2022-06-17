use std::env;
use std::fs;
use std::fs::File;
use std::io;
use std::path::Path;

// The standard fs::copy cannot be used as it also copies permissions. Bazel
// sets strict permissions for sandboxed files, and so subsequent calls fail
// with permission errors.
fn copy(from: &Path, to: &Path) -> io::Result<u64> {
    let mut reader = File::open(from)?;
    let mut writer = File::create(to)?;

    io::copy(&mut reader, &mut writer)
}

fn main() -> std::io::Result<()> {
    let args: Vec<String> = env::args().collect();

    let from = Path::new(&args[1]);
    let to = Path::new(&args[2]);

    fs::create_dir_all(&to.parent().unwrap())?;

    if let Err(e) = copy(&from, &to) {
        panic!("copy from {} to {}: {}", from.display(), to.display(), e);
    };

    Ok(())
}
