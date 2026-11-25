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
    {
        use base::config::keys;

        let mut display = config::DEFAULT_DISPLAY_SETTINGS.write().unwrap();
        for (key, value) in [
            (keys::OPTION_VIEW_STYLE, "adaptive"),
            (keys::OPTION_IMAGE_QUALITY, "balanced"),
            (keys::OPTION_CODEC_PREFERENCE, "auto"),
            (keys::OPTION_SHOW_QUALITY_MONITOR, "Y"),
            (keys::OPTION_SHOW_REMOTE_CURSOR, "Y"),
            (keys::OPTION_ZOOM_CURSOR, "Y"),
            (keys::OPTION_COLLAPSE_TOOLBAR, "Y"),
            (keys::OPTION_SHOW_MONITORS_TOOLBAR, "Y"),
            (keys::OPTION_ENABLE_FILE_COPY_PASTE, "Y"),
        ] {
            display.entry(key.to_owned()).or_insert_with(|| value.to_owned());
        }
        let mut local = config::DEFAULT_LOCAL_SETTINGS.write().unwrap();
        for key in [
            keys::OPTION_ENABLE_CONFIRM_CLOSING_TABS,
            keys::OPTION_ENABLE_OPEN_NEW_CONNECTIONS_IN_TABS,
            keys::OPTION_ENABLE_TCP_PUNCH,
            keys::OPTION_ENABLE_UDP_PUNCH,
            keys::OPTION_ENABLE_IPV6_PUNCH,
            keys::OPTION_ALLOW_SYNC_CLIPBOARD_BETWEEN_SESSIONS,
            keys::OPTION_KEEP_AWAKE_DURING_OUTGOING_SESSIONS,
            "allow-multi-edge-toolbar-dock",
            "allow-monitor-switch-main-toolbar",
        ] {
            local.entry(key.to_owned()).or_insert_with(|| "Y".to_owned());
        }
        let mut settings = config::DEFAULT_SETTINGS.write().unwrap();
        for key in [keys::OPTION_ENABLE_ABR, keys::OPTION_ENABLE_HWCODEC] {
            settings.entry(key.to_owned()).or_insert_with(|| "Y".to_owned());
        }
    }
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
