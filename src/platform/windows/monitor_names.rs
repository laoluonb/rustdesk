use std::{collections::HashMap, mem, ptr};
use winapi::um::{wingdi::*, winuser::*};

pub(crate) fn monitor_friendly_names() -> HashMap<String, String> {
    let mut names = HashMap::new();
    unsafe {
        let mut path_count = 0;
        let mut mode_count = 0;
        if GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &mut path_count, &mut mode_count) != 0 {
            return names;
        }
        let mut paths: Vec<DISPLAYCONFIG_PATH_INFO> = vec![mem::zeroed(); path_count as usize];
        let mut modes: Vec<DISPLAYCONFIG_MODE_INFO> = vec![mem::zeroed(); mode_count as usize];
        if QueryDisplayConfig(
            QDC_ONLY_ACTIVE_PATHS,
            &mut path_count,
            paths.as_mut_ptr(),
            &mut mode_count,
            modes.as_mut_ptr(),
            ptr::null_mut(),
        ) != 0
        {
            return names;
        }
        for path in paths.iter().take(path_count as usize) {
            let mut source: DISPLAYCONFIG_SOURCE_DEVICE_NAME = mem::zeroed();
            source.header._type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
            source.header.size = mem::size_of_val(&source) as _;
            source.header.adapterId = path.sourceInfo.adapterId;
            source.header.id = path.sourceInfo.id;
            if DisplayConfigGetDeviceInfo(&mut source.header) != 0 {
                continue;
            }
            let mut target: DISPLAYCONFIG_TARGET_DEVICE_NAME = mem::zeroed();
            target.header._type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
            target.header.size = mem::size_of_val(&target) as _;
            target.header.adapterId = path.targetInfo.adapterId;
            target.header.id = path.targetInfo.id;
            if DisplayConfigGetDeviceInfo(&mut target.header) != 0 {
                continue;
            }
            let label = wide_name(&target.monitorFriendlyDeviceName);
            if !label.is_empty() {
                names.entry(wide_name(&source.viewGdiDeviceName)).or_insert(label);
            }
        }
    }
    names
}

fn wide_name(value: &[u16]) -> String {
    let end = value.iter().position(|&v| v == 0).unwrap_or(value.len());
    String::from_utf16_lossy(&value[..end]).trim().to_owned()
}
