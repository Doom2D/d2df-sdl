program Doom2DF;
{$APPTYPE GUI}
{$HINTS OFF}

uses
  GL,
  GLExt,
  ENet in '../Lib/ENet/enet.pp',
  ENetTypes in '../Lib/ENet/enettypes.pp',
  ENetList in '../Lib/ENet/enetlist.pp',
  ENetTime in '../Lib/ENet/enettime.pp',
  ENetProtocol in '../Lib/ENet/enetprotocol.pp',
  ENetCallbacks in '../Lib/ENet/enetcallbacks.pp',
  ENetPlatform in '../Lib/ENet/enetplatform.pp',
  e_graphics in '../Engine Source/e_graphics.pas',
  e_input in '../Engine Source/e_input.pas',
  e_log in '../Engine Source/e_log.pas',
  e_sound in '../Engine Source/e_sound.pas',
  e_textures in '../Engine Source/e_textures.pas',
  e_fixedbuffer in '../Engine Source/e_fixedbuffer.pas',
  WADEDITOR in '../Shared Source/WADEDITOR.pas',
  WADSTRUCT in '../Shared Source/WADSTRUCT.pas',
  MAPSTRUCT in '../Shared Source/MAPSTRUCT.pas',
  MAPREADER in '../Shared Source/MAPREADER.pas',
  MAPDEF in '../Shared Source/MAPDEF.pas',
  CONFIG in '../Shared Source/CONFIG.pas',
  g_basic in 'g_basic.pas',
  g_console in 'g_console.pas',
  g_net in 'g_net.pas',
  g_netmsg in 'g_netmsg.pas',
  g_nethandler in 'g_nethandler.pas',
  g_netmaster in 'g_netmaster.pas',
  g_res_downloader in 'g_res_downloader.pas',
  g_game in 'g_game.pas',
  g_gfx in 'g_gfx.pas',
  g_gui in 'g_gui.pas',
  g_items in 'g_items.pas',
  g_main in 'g_main.pas',
  g_map in 'g_map.pas',
  g_menu in 'g_menu.pas',
  g_monsters in 'g_monsters.pas',
  g_options in 'g_options.pas',
  g_phys in 'g_phys.pas',
  g_player in 'g_player.pas',
  g_playermodel in 'g_playermodel.pas',
  g_saveload in 'g_saveload.pas',
  g_sound in 'g_sound.pas',
  g_textures in 'g_textures.pas',
  g_triggers in 'g_triggers.pas',
  g_weapons in 'g_weapons.pas',
  g_window in 'g_window.pas',
  sysutils,
  fmod in '../Lib/FMOD/fmod.pas',
  fmoderrors in '../Lib/FMOD/fmoderrors.pas',
  fmodpresets in '../Lib/FMOD/fmodpresets.pas',
  fmodtypes in '../Lib/FMOD/fmodtypes.pas',
  BinEditor in '../Shared Source/BinEditor.pas',
  g_panel in 'g_panel.pas',
  g_language in 'g_language.pas';

{$R *.res}
{$R CustomRes.res}

begin
  try
    Main();
    e_WriteLog('Shutdown with no errors.', MSG_NOTIFY);
  except
    on E: Exception do
      e_WriteLog(Format(_lc[I_SYSTEM_ERROR_MSG], [E.Message]), MSG_FATALERROR);
    else
      e_WriteLog(Format(_lc[I_SYSTEM_ERROR_UNKNOWN], [LongWord(ExceptAddr())]), MSG_FATALERROR);
  end;
end.
