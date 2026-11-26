fn main() {
    #[cfg(windows)]
    {
        use std::io::Write;
        let mut res = winres::WindowsResource::new();
        res.set_icon("../../res/icon.ico")
            .set("CompanyName", "laoluonb")
            .set("ProductName", "BlueBloom Remote")
            .set("FileDescription", "BlueBloom Remote (based on RustDesk)")
            .set_language(winapi::um::winnt::MAKELANGID(
                winapi::um::winnt::LANG_ENGLISH,
                winapi::um::winnt::SUBLANG_ENGLISH_US,
            ))
            .set_manifest_file("../../res/manifest.xml");
        match res.compile() {
            Err(e) => {
                write!(std::io::stderr(), "{}", e).unwrap();
                std::process::exit(1);
            }
            Ok(_) => {}
        }
    }
}
