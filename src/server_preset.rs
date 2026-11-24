use std::{
    net::{TcpStream, ToSocketAddrs},
    sync::{mpsc, Once},
    time::Duration,
};

use hbb_common::config::{self, Config};

pub const HOST: &str = "rustdesk.laoluowl.cn";
pub const API: &str = "https://rustdesk.laoluowl.cn";
pub const KEY: &str = "SYktxVV+CR+lrzdINS9jiTC8bicji7yHzJfmRnsrZgo=";
const ID_ADDRESS: &str = "rustdesk.laoluowl.cn:21116";
const PROBE_TIMEOUT: Duration = Duration::from_millis(1800);
static INITIALIZED: Once = Once::new();

pub fn is_automatic() -> bool {
    config::EXE_RENDEZVOUS_SERVER.read().unwrap().is_empty()
        && Config::get_option("custom-rendezvous-server").is_empty()
}

pub fn is_home(host: &str) -> bool {
    host == HOST || host == ID_ADDRESS
}

pub fn initialize() {
    INITIALIZED.call_once(|| {
        if !is_automatic() {
            return;
        }
        let (sender, receiver) = mpsc::channel();
        let probe = std::thread::Builder::new().spawn(move || {
            let reachable = ID_ADDRESS
                .to_socket_addrs()
                .ok()
                .and_then(|mut addresses| addresses.next())
                .is_some_and(|addr| TcpStream::connect_timeout(&addr, PROBE_TIMEOUT).is_ok());
            let _ = sender.send(reachable);
        });
        if probe.is_ok() {
            set_home(receiver.recv_timeout(PROBE_TIMEOUT).unwrap_or(false));
        }
    });
}

fn set_home(reachable: bool) -> bool {
    let mut selected = config::PROD_RENDEZVOUS_SERVER.write().unwrap();
    let next = if reachable { HOST } else { "" };
    if selected.as_str() == next {
        return false;
    }
    *selected = next.to_owned();
    true
}

#[cfg(not(target_os = "ios"))]
pub async fn refresh() -> bool {
    if !is_automatic() {
        return false;
    }
    let reachable = hbb_common::tokio::time::timeout(
        PROBE_TIMEOUT,
        hbb_common::socket_client::connect_tcp(ID_ADDRESS, PROBE_TIMEOUT.as_millis() as u64),
    )
    .await
    .map_or(false, |result| result.is_ok());
    is_automatic() && set_home(reachable)
}

pub fn automatic_credentials(host: &str) -> (&'static str, bool) {
    if is_home(host) {
        (KEY, true)
    } else {
        (config::RS_PUB_KEY, false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn credentials_are_scoped_to_the_selected_network() {
        assert_eq!(automatic_credentials(HOST), (KEY, true));
        assert_eq!(automatic_credentials(ID_ADDRESS), (KEY, true));
        assert_eq!(
            automatic_credentials(config::RENDEZVOUS_SERVERS[0]),
            (config::RS_PUB_KEY, false)
        );
        assert!(!is_home("rustdesk.laoluowl.cn.example:21116"));
    }
}
