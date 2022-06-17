//! Common utilities

pub mod starlark;

/// Convert a string into a valid crate module name by applying transforms to invalid characters
pub fn sanitize_module_name(name: &str) -> String {
    name.replace('-', "_")
}
