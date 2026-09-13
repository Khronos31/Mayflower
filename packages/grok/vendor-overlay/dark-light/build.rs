fn main() {
    let vendor = std::env::var("CARGO_CFG_TARGET_VENDOR").unwrap_or_default();
    let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if vendor == "apple" && os == "macos" {
        println!("cargo:rustc-link-lib=framework=AppKit");
    }
}
