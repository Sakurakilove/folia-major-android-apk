// Generated from electron/main.cjs by extractDesktop.cjs.
function normalizeUpdateChannelSelection(value) {
  const channel = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return channel === 'realeco' || channel === 'limo' || channel === 'cielo' ? channel : null;
}
const booleanKeys=new Set(["MINIMIZE_TO_TRAY","CLOSE_TO_TRAY","HIDE_TASKBAR_ICON","REMOTE_CONTROL_ALWAYS_ON_TOP","REMOTE_CONTROL_SKIP_TASKBAR","REMOTE_CONTROL_HIDE_TITLEBAR","REMOTE_CONTROL_CLICK_THROUGH","TRANSPARENT_PLAYER_BACKGROUND","DISCORD_RICH_PRESENCE_ENABLED","VOICE_INPUT_PAUSE_ENABLED","PREVENT_DISPLAY_SLEEP_DURING_PLAYBACK","MOD_SYSTEM_ENABLED","wallpaper_mode","wallpaper_forward_mouse","wallpaper_zguard","wallpaper_mac_autohide_dock"]);
module.exports=(key,value)=>{if(key==='UPDATE_CHANNEL'){const channel=normalizeUpdateChannelSelection(value);return {accepted:channel!==null,value:channel};}return {accepted:true,value:booleanKeys.has(key)?Boolean(value):value};};
