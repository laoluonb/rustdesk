use hbb_common::config::{self, Config};

pub const HOST: &str = "rustdesk.laoluowl.cn";
pub const API: &str = "https://rustdesk.laoluowl.cn";
pub const KEY: &str = "SYktxVV+CR+lrzdINS9jiTC8bicji7yHzJfmRnsrZgo=";
pub const ID_ADDRESS: &str = "rustdesk.laoluowl.cn:21116";

pub fn is_automatic() -> bool {
    config::EXE_RENDEZVOUS_SERVER.read().unwrap().is_empty()
        && Config::get_option("custom-rendezvous-server").is_empty()
}

pub fn is_home(host: &str) -> bool {
    host == HOST || host == ID_ADDRESS
}

pub fn initialize() {
    *config::PROD_RENDEZVOUS_SERVER.write().unwrap() = HOST.to_owned();
    #[cfg(all(feature = "flutter", not(any(target_os = "ios", target_os = "android"))))]
    config::DEFAULT_DISPLAY_SETTINGS
        .write()
        .unwrap()
        .entry("show_quality_monitor".to_owned())
        .or_insert_with(|| "Y".to_owned());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn home_key_is_scoped_to_the_home_server() {
        assert!(is_home(HOST));
        assert!(is_home(ID_ADDRESS));
        assert!(!is_home(config::RENDEZVOUS_SERVERS[0]));
        assert!(!is_home("rustdesk.laoluowl.cn.example:21116"));
    }
}
