unit e_input;

interface

uses
  SysUtils,
  e_log,
  SDL;

const
  e_MaxKbdKeys  = 321;
  e_MaxJoys     = 2;
  e_MaxJoyBtns  = 32;
  e_MaxJoyAxes  = 4;
  e_MaxJoyHats  = 4;
  
  e_MaxJoyKeys = e_MaxJoyBtns + e_MaxJoyAxes*2 + e_MaxJoyHats*4;
  
  e_MaxInputKeys = e_MaxKbdKeys + e_MaxJoys*e_MaxJoyKeys - 1;
  // $$$..$$$ -  321 Keyboard buttons/keys
  // $$$..$$$ - 4*32 Joystick buttons
  // $$$..$$$ -  4*4 Joystick axes (+ and -)
  // $$$..$$$ -  4*4 Joystick hats (L U R D)

  IK_INVALID = 65535;
  
  // these are apparently used in g_gui and g_game and elsewhere
  IK_UNKNOWN = SDLK_UNKNOWN;
	IK_FIRST   = SDLK_FIRST;
  IK_ESCAPE  = SDLK_ESCAPE;
  IK_RETURN  = SDLK_RETURN;
  IK_ENTER   = SDLK_RETURN;
  IK_UP      = SDLK_UP;
  IK_DOWN    = SDLK_DOWN;
  IK_LEFT    = SDLK_LEFT;
  IK_RIGHT   = SDLK_RIGHT;
  IK_DELETE  = SDLK_DELETE;
  IK_HOME    = SDLK_HOME;
  IK_INSERT  = SDLK_INSERT;
  IK_SPACE   = SDLK_SPACE;
  IK_CONTROL = SDLK_LCTRL;
  IK_SHIFT   = SDLK_LSHIFT;
  IK_TAB     = SDLK_TAB;
  IK_PAGEUP  = SDLK_PAGEUP;
  IK_PAGEDN  = SDLK_PAGEDOWN; 
  IK_F2      = SDLK_F2;
  IK_F3      = SDLK_F3;
  IK_F4      = SDLK_F4;
  IK_F5      = SDLK_F5;
  IK_F6      = SDLK_F6;
  IK_F7      = SDLK_F7;
  IK_F8      = SDLK_F8;
  IK_F9      = SDLK_F9;
  IK_F10     = SDLK_F10;
  IK_END     = SDLK_END;
  IK_BACKSPACE = SDLK_BACKSPACE;
  IK_BACKQUOTE = SDLK_BACKQUOTE;
  IK_PAUSE   = SDLK_PAUSE;
  // TODO: think of something better than this shit
  IK_LASTKEY = 320;
  
function  e_InitInput(): Boolean;
procedure e_ReleaseInput();
procedure e_ClearInputBuffer();
function  e_PollInput(): Boolean;
function  e_KeyPressed(Key: Word): Boolean;
function  e_AnyKeyPressed(): Boolean;
function  e_GetFirstKeyPressed(): Word;
function  e_JoystickStateToString(mode: Integer): String;
procedure e_SetKeyState(key: Word; pressed: Boolean);

var
  {e_MouseInfo:          TMouseInfo;}
  e_EnableInput:        Boolean = False;
  e_JoysticksAvailable: Byte    = 0;
  e_KeyNames:           array [0..e_MaxInputKeys] of String;

implementation

const
  KBRD_END = e_MaxKbdKeys;
  JOYK_BEG = KBRD_END;
  JOYK_END = JOYK_BEG + e_MaxJoyKeys*e_MaxJoys;
  JOYA_BEG = JOYK_END;
  JOYA_END = JOYA_BEG + e_MaxJoyAxes*2*e_MaxJoys;
  JOYH_BEG = JOYA_END;
  JOYH_END = JOYH_BEG + e_MaxJoyHats*4*e_MaxJoys;

type
  TJoystick = record
    ID:      Byte;
    Handle:  PSDL_Joystick;
	  Axes:    Byte;
	  Buttons: Byte;
	  Hats:    Byte;
  end;

var
  KeyBuffer: array [0..e_MaxKbdKeys] of Boolean;
  Joysticks: array of TJoystick;        

function OpenJoysticks(): Byte;
var
  i, k, c: Integer;
  joy: PSDL_Joystick;
begin
  k := SDL_NumJoysticks();
  c := 0;
  for i := 0 to k do
  begin
    joy := SDL_JoystickOpen(i);
	if joy <> nil then
	begin
	  Inc(c);
	  e_WriteLog('Input: Opened SDL joystick ' + IntToStr(i) + ' as joystick ' + IntToStr(c) + ':', MSG_NOTIFY);
	  SetLength(Joysticks, c);
	  with Joysticks[c-1] do
	  begin
	    ID := i;
		Handle := joy;
		Axes := SDL_JoystickNumAxes(joy);
		Buttons := SDL_JoystickNumButtons(joy);
		Hats := SDL_JoystickNumHats(joy);
	    e_WriteLog('       ' + IntToStr(Axes) + ' axes, ' + IntToStr(Buttons) + ' buttons, ' +
	               IntToStr(Hats) + ' hats.', MSG_NOTIFY);
	  end;
	end;
  end;
  
  Result := c;
end;

procedure ReleaseJoysticks();
var
  i: Integer;
begin
  for i := Low(Joysticks) to High(Joysticks) do
    with Joysticks[i] do
      SDL_JoystickClose(Handle);
  SetLength(Joysticks, 0);
end;
  
function PollKeyboard(): Boolean;
begin
  Result := True;
end;  
  
function PollJoysticks(): Boolean;
begin
  Result := False;
end;    

procedure GenerateKeyNames();
var
  i, j, k: LongWord;
begin
  // keyboard key names
  for i := 0 to IK_LASTKEY do
    e_KeyNames[i] := SDL_GetKeyName(i);
    
  // joysticks
  for j := 0 to e_MaxJoys-1 do
  begin
    k := IK_LASTKEY + j * e_MaxJoyKeys + 1;
    // buttons
    for i := 0 to e_MaxJoyBtns-1 do
      e_KeyNames[k + i] := Format('JOY%d B%d', [j, i]);
    k := k + e_MaxJoyBtns;
    // axes
    for i := 0 to e_MaxJoyAxes-1 do
    begin
      e_KeyNames[k + i*2    ] := Format('JOY%d A%d+', [j, i]);
      e_KeyNames[k + i*2 + 1] := Format('JOY%d A%d-', [j, i]);
    end;
    k := k + e_MaxJoyAxes*2;
    // hats
    for i := 0 to e_MaxJoyHats-1 do
    begin
      e_KeyNames[k + i*4    ] := Format('JOY%d D%dL', [j, i]);
      e_KeyNames[k + i*4 + 1] := Format('JOY%d D%dU', [j, i]);
      e_KeyNames[k + i*4 + 2] := Format('JOY%d D%dR', [j, i]);
      e_KeyNames[k + i*4 + 3] := Format('JOY%d D%dD', [j, i]);
    end;
  end;
end;
  
function e_InitInput(): Boolean;
begin
  Result := False;
  
  e_JoysticksAvailable := OpenJoysticks();
  e_EnableInput := True;
  GenerateKeyNames();

  Result := True;
end;

procedure e_ReleaseInput();
begin
  ReleaseJoysticks();
  e_JoysticksAvailable := 0;
end;
                                                         
procedure e_ClearInputBuffer();
var
  i: Integer;
begin
  for i := 0 to KBRD_END-1 do
    KeyBuffer[i] := False;
end;

function e_PollInput(): Boolean;
var
  kb, js: Boolean;
begin
  kb := PollKeyboard();
  js := PollJoysticks();

  Result := kb or js;
end;

function e_KeyPressed(Key: Word): Boolean;
begin
  if (Key < KBRD_END) then
  begin // Keyboard buttons/keys
    Result := KeyBuffer[Key];
  end
  else if (Key >= JOYK_BEG) and (Key < JOYK_END) then
  begin // Joystick buttons
    Key := Key - JOYK_BEG;
    Result := False;
  end
  else if (Key >= JOYA_BEG) and (Key < JOYA_END) then
  begin // Joystick axes      
  end
  else if (Key >= JOYH_BEG) and (Key < JOYH_END) then
  begin // Joystick hats            
  end
  else
    Result := False;
end;

procedure e_SetKeyState(key: Word; pressed: Boolean);
begin
  if (Key < KBRD_END) then
  begin // Keyboard buttons/keys
    keyBuffer[key] := pressed;
  end
  else if (Key >= JOYK_BEG) and (Key < JOYK_END) then
  begin // Joystick buttons
    Key := Key - JOYK_BEG;
  end
  else if (Key >= JOYA_BEG) and (Key < JOYA_END) then
  begin // Joystick axes      
  end
  else if (Key >= JOYH_BEG) and (Key < JOYH_END) then
  begin // Joystick hats            
  end;
end;

function e_AnyKeyPressed(): Boolean;
var
  k: Word;
begin
  Result := False;

  for k := 0 to e_MaxInputKeys do
    if e_KeyPressed(k) then
    begin
      Result := True;
      Break;
    end;
end;

function e_GetFirstKeyPressed(): Word;
var
  k: Word;
begin
  Result := IK_INVALID;

  for k := 0 to e_MaxInputKeys do
    if e_KeyPressed(k) then
    begin
      Result := k;
      Break;
    end;
end;

////////////////////////////////////////////////////////////////////////////////

function e_JoystickStateToString(mode: Integer): String;
begin
  Result := '';
end;

end.
