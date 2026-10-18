// Generated from electron/main.cjs by extractDesktop.cjs.
module.exports=({store,aiCredentials,app})=>{
const MINIMIZE_TO_TRAY_SETTING_KEY="MINIMIZE_TO_TRAY";
const CLOSE_TO_TRAY_SETTING_KEY="CLOSE_TO_TRAY";
const HIDE_TASKBAR_ICON_SETTING_KEY="HIDE_TASKBAR_ICON";
const REMOTE_CONTROL_ALWAYS_ON_TOP_SETTING_KEY="REMOTE_CONTROL_ALWAYS_ON_TOP";
const REMOTE_CONTROL_SKIP_TASKBAR_SETTING_KEY="REMOTE_CONTROL_SKIP_TASKBAR";
const REMOTE_CONTROL_HIDE_TITLEBAR_SETTING_KEY="REMOTE_CONTROL_HIDE_TITLEBAR";
const REMOTE_CONTROL_CLICK_THROUGH_SETTING_KEY="REMOTE_CONTROL_CLICK_THROUGH";
const MAIN_WINDOW_ALWAYS_ON_TOP_SETTING_KEY="MAIN_WINDOW_ALWAYS_ON_TOP";
const TRANSPARENT_PLAYER_BACKGROUND_SETTING_KEY="TRANSPARENT_PLAYER_BACKGROUND";
const DISCORD_RICH_PRESENCE_ENABLED_SETTING_KEY="DISCORD_RICH_PRESENCE_ENABLED";
const LYRIC_API_ENABLED_SETTING_KEY="LYRIC_API_ENABLED";
const VOICE_INPUT_PAUSE_ENABLED_SETTING_KEY="VOICE_INPUT_PAUSE_ENABLED";
const PREVENT_DISPLAY_SLEEP_DURING_PLAYBACK_SETTING_KEY="PREVENT_DISPLAY_SLEEP_DURING_PLAYBACK";
const MOD_SYSTEM_ENABLED_SETTING_KEY="MOD_SYSTEM_ENABLED";
const UPDATE_CHANNEL_SETTING_KEY="UPDATE_CHANNEL";
const WALLPAPER_MODE_SETTING_KEY="wallpaper_mode";
const WALLPAPER_MAC_AUTOHIDE_DOCK_SETTING_KEY="wallpaper_mac_autohide_dock";
const wallpaperWindowsAttachMode=null;
const isWallpaperModeEnabled=()=>require('./../electron/wallpaper/wallpaperWatchdog.cjs').isWallpaperModeEnabled(store);
const getCurrentReleaseChannel=()=>require('./../electron/updateChannels.cjs').resolveReleaseChannel(app.getVersion(),store.get(UPDATE_CHANNEL_SETTING_KEY)||'realeco');
function readStoredBoolean(settingKey, fallback = false) {
  const value = store.get(settingKey);

  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true') {
      return true;
    }
    if (normalized === 'false') {
      return false;
    }
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  return fallback;
}
function getPublicSettings() {
  return {
    ...aiCredentials.toPublicSettings(store.store),
    [MINIMIZE_TO_TRAY_SETTING_KEY]: readStoredBoolean(MINIMIZE_TO_TRAY_SETTING_KEY, false),
    [CLOSE_TO_TRAY_SETTING_KEY]: readStoredBoolean(CLOSE_TO_TRAY_SETTING_KEY, false),
    [HIDE_TASKBAR_ICON_SETTING_KEY]: readStoredBoolean(HIDE_TASKBAR_ICON_SETTING_KEY, false),
    [REMOTE_CONTROL_ALWAYS_ON_TOP_SETTING_KEY]: readStoredBoolean(REMOTE_CONTROL_ALWAYS_ON_TOP_SETTING_KEY, true),
    [REMOTE_CONTROL_SKIP_TASKBAR_SETTING_KEY]: readStoredBoolean(REMOTE_CONTROL_SKIP_TASKBAR_SETTING_KEY, false),
    [REMOTE_CONTROL_HIDE_TITLEBAR_SETTING_KEY]: readStoredBoolean(REMOTE_CONTROL_HIDE_TITLEBAR_SETTING_KEY, false),
    [REMOTE_CONTROL_CLICK_THROUGH_SETTING_KEY]: readStoredBoolean(REMOTE_CONTROL_CLICK_THROUGH_SETTING_KEY, false),
    [MAIN_WINDOW_ALWAYS_ON_TOP_SETTING_KEY]: readStoredBoolean(MAIN_WINDOW_ALWAYS_ON_TOP_SETTING_KEY, false),
    [TRANSPARENT_PLAYER_BACKGROUND_SETTING_KEY]: readStoredBoolean(TRANSPARENT_PLAYER_BACKGROUND_SETTING_KEY, false),
    [DISCORD_RICH_PRESENCE_ENABLED_SETTING_KEY]: readStoredBoolean(DISCORD_RICH_PRESENCE_ENABLED_SETTING_KEY, false),
    [LYRIC_API_ENABLED_SETTING_KEY]: readStoredBoolean(LYRIC_API_ENABLED_SETTING_KEY, false),
    [VOICE_INPUT_PAUSE_ENABLED_SETTING_KEY]: readStoredBoolean(VOICE_INPUT_PAUSE_ENABLED_SETTING_KEY, false),
    [PREVENT_DISPLAY_SLEEP_DURING_PLAYBACK_SETTING_KEY]: readStoredBoolean(PREVENT_DISPLAY_SLEEP_DURING_PLAYBACK_SETTING_KEY, false),
    [MOD_SYSTEM_ENABLED_SETTING_KEY]: readStoredBoolean(MOD_SYSTEM_ENABLED_SETTING_KEY, false),
    [UPDATE_CHANNEL_SETTING_KEY]: getCurrentReleaseChannel().id,
    'enable_player_page_native_blur': store.get('enable_player_page_native_blur') === true,
    'wallpaper_attach_mode': process.platform === 'win32' ? wallpaperWindowsAttachMode : null,
    [WALLPAPER_MODE_SETTING_KEY]: isWallpaperModeEnabled(),
    [WALLPAPER_MAC_AUTOHIDE_DOCK_SETTING_KEY]: readStoredBoolean(WALLPAPER_MAC_AUTOHIDE_DOCK_SETTING_KEY, true),
  };
}
return Object.assign(getPublicSettings,{readStoredBoolean});};
