fn main() {
    ["cargo", "rustc"].iter().for_each(|target| {
        let mut args = std::env::args().skip(1);

        let value = args
            .find_map(|arg| {
                arg.strip_prefix(&format!("--{}=", target))
                    .map(|s| s.to_string())
            })
            .unwrap_or_else(|| panic!("missing flag for {}", target));

        let want_prefix = "bazel-out/";
        assert!(
            value.starts_with(want_prefix),
            "want prefix {} for {}",
            want_prefix,
            value,
        );

        let want_suffix = &format!("/bin/{}", target);
        assert!(
            value.ends_with(want_suffix),
            "want suffix {} for {}",
            want_suffix,
            value
        );
    });
}
