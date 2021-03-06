unit g_phys;

interface

uses
  e_graphics;

type
  PObj = ^TObj;
  TObj = record
    X, Y:    Integer;
    Rect:    TRectWH;
    Vel:     TPoint2i;
    Accel:   TPoint2i;
  end;

const
  MAX_YV = 30;
  LIMIT_VEL   = 16384;
  LIMIT_ACCEL = 1024;

  MOVE_NONE       = 0;
  MOVE_HITWALL    = 1;
  MOVE_HITCEIL    = 2;
  MOVE_HITLAND    = 4;
  MOVE_FALLOUT    = 8;
  MOVE_INWATER    = 16;
  MOVE_HITWATER   = 32;
  MOVE_HITAIR     = 64;
  MOVE_BLOCK      = 128;

procedure g_Obj_Init(Obj: PObj);
function  g_Obj_Move(Obj: PObj; Fallable: Boolean; Splash: Boolean; ClimbSlopes: Boolean = False): Word;
function  g_Obj_Collide(Obj1, Obj2: PObj): Boolean; overload;
function  g_Obj_Collide(X, Y: Integer; Width, Height: Word; Obj: PObj): Boolean; overload;
function  g_Obj_CollidePoint(X, Y: Integer; Obj: PObj): Boolean;
function  g_Obj_CollideLevel(Obj: PObj; XInc, YInc: Integer): Boolean;
function  g_Obj_CollideStep(Obj: PObj; XInc, YInc: Integer): Boolean;
function  g_Obj_CollideWater(Obj: PObj; XInc, YInc: Integer): Boolean;
function  g_Obj_CollideLiquid(Obj: PObj; XInc, YInc: Integer): Boolean;
function  g_Obj_CollidePanel(Obj: PObj; XInc, YInc: Integer; PanelType: Word): Boolean;
function  g_Obj_StayOnStep(Obj: PObj): Boolean;
procedure g_Obj_Push(Obj: PObj; VelX, VelY: Integer);
procedure g_Obj_PushA(Obj: PObj; Vel: Integer; Angle: SmallInt);
procedure g_Obj_SetSpeed(Obj: PObj; s: Integer);
function  z_dec(a, b: Integer): Integer;
function  z_fdec(a, b: Double): Double;

var
  gMon: Boolean = False;

implementation

uses
  g_map, g_basic, Math, g_player, g_console, SysUtils,
  g_sound, g_gfx, MAPDEF, g_monsters, g_game, BinEditor;

function g_Obj_StayOnStep(Obj: PObj): Boolean;
begin
  Result := not g_Map_CollidePanel(Obj^.X+Obj^.Rect.X, Obj^.Y+Obj^.Rect.Y+Obj^.Rect.Height-1,
                                   Obj^.Rect.Width, 1,
                                   PANEL_STEP, False)
            and g_Map_CollidePanel(Obj^.X+Obj^.Rect.X, Obj^.Y+Obj^.Rect.Y+Obj^.Rect.Height,
                                   Obj^.Rect.Width, 1,
                                   PANEL_STEP, False);
end;

function CollideLiquid(Obj: PObj; XInc, YInc: Integer): Boolean;
begin
  Result := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj^.Rect.Y+YInc,
                               Obj^.Rect.Width, Obj^.Rect.Height*2 div 3,
                               PANEL_WATER or PANEL_ACID1 or PANEL_ACID2, False);
end;

function CollideLift(Obj: PObj; XInc, YInc: Integer): Integer;
begin
  if g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj^.Rect.Y+YInc,
                        Obj^.Rect.Width, Obj^.Rect.Height,
                        PANEL_LIFTUP, False) then
    Result := -1
  else if g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj^.Rect.Y+YInc,
                          Obj^.Rect.Width, Obj^.Rect.Height,
                          PANEL_LIFTDOWN, False) then
    Result := 1
  else
    Result := 0;
end;

function CollideHorLift(Obj: PObj; XInc, YInc: Integer): Integer;
var
  left, right: Boolean;
begin
  left := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj^.Rect.Y+YInc,
                             Obj^.Rect.Width, Obj^.Rect.Height,
                             PANEL_LIFTLEFT, False);
  right := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj^.Rect.Y+YInc,
                             Obj^.Rect.Width, Obj^.Rect.Height,
                             PANEL_LIFTRIGHT, False);
  if left and not right then
    Result := -1
  else if right and not left then
    Result := 1
  else
    Result := 0;
end;

function CollidePlayers(_Obj: PObj; XInc, YInc: Integer): Boolean;
var
  a: Integer;
begin
  Result := False;

  if gPlayers = nil then
    Exit;

  for a := 0 to High(gPlayers) do
    if gPlayers[a] <> nil then
      with gPlayers[a] do
        if Live and
           g_Collide(GameX+PLAYER_RECT.X, GameY+PLAYER_RECT.Y,
                     PLAYER_RECT.Width, PLAYER_RECT.Height,
                     _Obj^.X+_Obj^.Rect.X+XInc, _Obj^.Y+_Obj^.Rect.Y+YInc,
                     _Obj^.Rect.Width, _Obj^.Rect.Height) then
        begin
          Result := True;
          Exit;
        end;
end;

function CollideMonsters(Obj: PObj; XInc, YInc: Integer): Boolean;
var
  a: Integer;
begin
  Result := False;

  if gMonsters = nil then
    Exit;

  for a := 0 to High(gMonsters) do
    if gMonsters[a] <> nil then
      if gMonsters[a].Live and
         gMonsters[a].Collide(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj^.Rect.Y+YInc,
                              Obj^.Rect.Width, Obj^.Rect.Height) then
      begin
        Result := True;
        Exit;
      end;
end;

function Blocked(Obj: PObj; XInc, YInc: Integer): Boolean;
begin
  Result := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj.Rect.Y+YInc,
                               Obj^.Rect.Width, Obj^.Rect.Height,
                               PANEL_BLOCKMON, False);
end;

function g_Obj_CollideLevel(Obj: PObj; XInc, YInc: Integer): Boolean;
begin
  Result := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj.Rect.Y+YInc,
                               Obj^.Rect.Width, Obj^.Rect.Height,
                               PANEL_WALL, False);
end;

function g_Obj_CollideStep(Obj: PObj; XInc, YInc: Integer): Boolean;
begin
  Result := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj.Rect.Y+YInc,
                               Obj^.Rect.Width, Obj^.Rect.Height,
                               PANEL_STEP, False);
end;

function g_Obj_CollideWater(Obj: PObj; XInc, YInc: Integer): Boolean;
begin
  Result := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj.Rect.Y+YInc,
                               Obj^.Rect.Width, Obj^.Rect.Height,
                               PANEL_WATER, False);
end;

function g_Obj_CollideLiquid(Obj: PObj; XInc, YInc: Integer): Boolean;
begin
  Result := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj.Rect.Y+YInc,
                               Obj^.Rect.Width, Obj^.Rect.Height,
                               PANEL_WATER or PANEL_ACID1 or PANEL_ACID2, False);
end;

function g_Obj_CollidePanel(Obj: PObj; XInc, YInc: Integer; PanelType: Word): Boolean;
begin
  Result := g_Map_CollidePanel(Obj^.X+Obj^.Rect.X+XInc, Obj^.Y+Obj.Rect.Y+YInc,
                               Obj^.Rect.Width, Obj^.Rect.Height,
                               PanelType, False);
end;

procedure g_Obj_Splash(Obj: PObj; Color: Byte);
var
  MaxVel: Integer;
begin
  MaxVel := Max(Abs(Obj^.Vel.X), Abs(Obj^.Vel.Y));
  if MaxVel > 4 then begin
    if MaxVel < 10 then
      g_Sound_PlayExAt('SOUND_GAME_BULK1', Obj^.X, Obj^.Y)
    else
      g_Sound_PlayExAt('SOUND_GAME_BULK2', Obj^.X, Obj^.Y);
  end;

  g_GFX_Water(Obj^.X+Obj^.Rect.X+(Obj^.Rect.Width div 2),
              Obj^.Y+Obj^.Rect.Y+(Obj^.Rect.Height div 2),
              Min(5*(Abs(Obj^.Vel.X)+Abs(Obj^.Vel.Y)), 50),
              -Obj^.Vel.X, -Obj^.Vel.Y,
              Obj^.Rect.Width, 16, Color);
end;

function move(Obj: PObj; dx, dy: Integer; ClimbSlopes: Boolean): Word;
var
  i: Integer;
  sx, sy: ShortInt;
  st: Word;

  procedure slope(s: Integer);
  var
    i: Integer;
  begin
    i := 0;
    while g_Obj_CollideLevel(Obj, sx, 0) and (i < 4) do
    begin
      Obj^.Y := Obj^.Y + s;
      Inc(i);
    end;
    Obj^.X := Obj^.X + sx;
  end;

  function movex(): Boolean;
  begin
    Result := False;

  // ���� ������� ������� � �������, � ��� �������:
    if gMon and not WordBool(st and MOVE_BLOCK) then
      if Blocked(Obj, sx, 0) then
        st := st or MOVE_BLOCK;

  // ���� ������� � �������, � ��� ����� => ������ ������:
    if g_Obj_CollideLevel(Obj, sx, 0) then
      begin
        if ClimbSlopes and (Abs(dy) < 2) then
          begin
            Result := True;
            if (not g_Obj_CollideLevel(Obj, sx, -12)) // ���������� �� 12 �������� �����/������
            and g_Obj_CollidePanel(Obj, 0, 1, PANEL_WALL or PANEL_STEP) // ������ ���� ���� ����� ��� ������
            then
              slope(-1)
            else
              begin
                Result := False;
                st := st or MOVE_HITWALL;
              end;
          end
          else
            st := st or MOVE_HITWALL;
      end
    else // ��� ����� ���
      begin
        if CollideLiquid(Obj, sx, 0) then
          begin // ���� ������� � �������, � ��� ������ ��������
            if not WordBool(st and MOVE_INWATER) then
              st := st or MOVE_HITWATER;
          end
        else // ���� ������� � �������, � ��� ��� ��� ��������
          if WordBool(st and MOVE_INWATER) then
            st := st or MOVE_HITAIR;

      // ���:
        Obj^.X := Obj^.X + sx;
        Result := True;
      end;
  end;

  function movey(): Boolean;
  begin
    Result := False;

  // ���� ������� ������� �� ���������, � ��� �������:
    if gMon and not WordBool(st and MOVE_BLOCK) then
      if Blocked(Obj, 0, sy) then
        st := st or MOVE_BLOCK;

  // ���� ������� � �� ���������, � ��� ����� => ������ ������:
  // ��� ���� ������� ����, � ��� ������� => ������ ������:
    if g_Obj_CollideLevel(Obj, 0, sy) or
       ((sy > 0) and g_Obj_StayOnStep(Obj)) then
      begin
        if sy > 0 then
          st := st or MOVE_HITLAND
        else
          st := st or MOVE_HITCEIL;
      end
    else // ��� ����� ���. � ������� ����� ���� ���
      begin
        if CollideLiquid(Obj, 0, sy) then
          begin // ���� ������� � �� ���������, � ��� ������ ��������
            if not WordBool(st and MOVE_INWATER) then
              st := st or MOVE_HITWATER;
          end
        else // ���� ������� � �� ���������, � ��� ��� ��� ��������
          if WordBool(st and MOVE_INWATER) then
            st := st or MOVE_HITAIR;

      // ���:
        Obj^.Y := Obj^.Y + sy;

        Result := True;
      end;
  end;

begin
  st := MOVE_NONE;

// ������ � ��������:
  if CollideLiquid(Obj, 0, 0) then
    st := st or MOVE_INWATER;

// ������ � ��������:
  if gMon then
    if Blocked(Obj, 0, 0) then
      st := st or MOVE_BLOCK;

// ��������� �� ����:
  if (dx = 0) and (dy = 0) then
  begin
    Result := st;
    Exit;
  end;

  sx := g_basic.Sign(dx);
  sy := g_basic.Sign(dy);
  dx := Abs(dx);
  dy := Abs(dy);

  for i := 1 to dx do
    if not movex() then
      Break;

  for i := 1 to dy do
    if not movey() then
      Break;

  Result := st;
end;

procedure g_Obj_Init(Obj: PObj);
begin
  ZeroMemory(Obj, SizeOf(TObj));
end;

function g_Obj_Move(Obj: PObj; Fallable: Boolean; Splash: Boolean; ClimbSlopes: Boolean = False): Word;
var
  xv, yv, dx, dy: Integer;
  inwater: Boolean;
  c: Boolean;
  wtx: DWORD;
label
  _move;
begin
// ������ �� �������� � ���������
  if      Obj^.Vel.X < -LIMIT_VEL then Obj^.Vel.X := -LIMIT_VEL
  else if Obj^.Vel.X >  LIMIT_VEL then Obj^.Vel.X :=  LIMIT_VEL;
  if      Obj^.Vel.Y < -LIMIT_VEL then Obj^.Vel.Y := -LIMIT_VEL
  else if Obj^.Vel.Y >  LIMIT_VEL then Obj^.Vel.Y :=  LIMIT_VEL;
  if      Obj^.Accel.X < -LIMIT_ACCEL then Obj^.Accel.X := -LIMIT_ACCEL
  else if Obj^.Accel.X >  LIMIT_ACCEL then Obj^.Accel.X :=  LIMIT_ACCEL;
  if      Obj^.Accel.Y < -LIMIT_ACCEL then Obj^.Accel.Y := -LIMIT_ACCEL
  else if Obj^.Accel.Y >  LIMIT_ACCEL then Obj^.Accel.Y :=  LIMIT_ACCEL;

// ������� �� ������ ������� �����:
  if Obj^.Y > gMapInfo.Height+128 then
  begin
    Result := MOVE_FALLOUT;
    Exit;
  end;

// ������ �������� � ��������� ������ �� ������ ������:
  c := gTime mod (GAME_TICK*2) <> 0;

  if c then
    goto _move;

  case CollideLift(Obj, 0, 0) of
    -1: //up
      begin
        Obj^.Vel.Y := Obj^.Vel.Y - 1; // ���� �����
        if Obj^.Vel.Y < -5 then
          Obj^.Vel.Y := Obj^.Vel.Y + 1;
      end;

    1: //down
      begin
        if Obj^.Vel.Y > 5 then
          Obj^.Vel.Y := Obj^.Vel.Y - 1;
        Obj^.Vel.Y := Obj^.Vel.Y + 1; // ���������� ��� ���� ����
      end;

    0:
      begin
        if Fallable then
          Obj^.Vel.Y := Obj^.Vel.Y + 1; // ����������
        if Obj^.Vel.Y > MAX_YV then
          Obj^.Vel.Y := Obj^.Vel.Y - 1;
      end;
  end;

  case CollideHorLift(Obj, 0, 0) of
    -1: //left
      begin
        Obj^.Vel.X := Obj^.Vel.X - 3; // ���� �����
        if Obj^.Vel.X < -9 then
          Obj^.Vel.X := Obj^.Vel.X + 3;
      end;

    1: //right
      begin
        Obj^.Vel.X := Obj^.Vel.X + 3;
        if Obj^.Vel.X > 9 then
          Obj^.Vel.X := Obj^.Vel.X - 3;
      end;
    // 0 is not needed here
  end;

  inwater := CollideLiquid(Obj, 0, 0);
  if inwater then
  begin
    xv := Abs(Obj^.Vel.X)+1;
    if xv > 5 then
      Obj^.Vel.X := z_dec(Obj^.Vel.X, (xv div 2)-2);

    yv := Abs(Obj^.Vel.Y)+1;
    if yv > 5 then
      Obj^.Vel.Y := z_dec(Obj^.Vel.Y, (yv div 2)-2);

    xv := Abs(Obj^.Accel.X)+1;
    if xv > 5 then
      Obj^.Accel.X := z_dec(Obj^.Accel.X, (xv div 2)-2);

    yv := Abs(Obj^.Accel.Y)+1;
    if yv > 5 then
      Obj^.Accel.Y := z_dec(Obj^.Accel.Y, (yv div 2)-2);
  end;

// ��������� �������� � ��������:
  Obj^.Accel.X := z_dec(Obj^.Accel.X, 1);
  Obj^.Accel.Y := z_dec(Obj^.Accel.Y, 1);

_move:

  xv := Obj^.Vel.X + Obj^.Accel.X;
  yv := Obj^.Vel.Y + Obj^.Accel.Y;

  dx := xv;
  dy := yv;

  Result := move(Obj, dx, dy, ClimbSlopes);

// ������ (���� �����):
  if Splash then
    if WordBool(Result and MOVE_HITWATER) then
    begin
      wtx := g_Map_CollideLiquid_Texture(Obj^.X+Obj^.Rect.X,
                                         Obj^.Y+Obj^.Rect.Y,
                                         Obj^.Rect.Width,
                                         Obj^.Rect.Height*2 div 3);
      case wtx of
        TEXTURE_SPECIAL_WATER:
          g_Obj_Splash(Obj, 3);
        TEXTURE_SPECIAL_ACID1:
          g_Obj_Splash(Obj, 2);
        TEXTURE_SPECIAL_ACID2:
          g_Obj_Splash(Obj, 1);
        TEXTURE_NONE:
          ;
        else
          g_Obj_Splash(Obj, 0);
      end;
    end;

// ������ �������� � ��������� ������ �� ������ ������:
  if c then
    Exit;

// ��������� � ����� - ����:
  if WordBool(Result and MOVE_HITWALL) then
  begin
    Obj^.Vel.X := 0;
    Obj^.Accel.X := 0;
  end;

// ��������� � ��� ��� ������� - ����:
  if WordBool(Result and (MOVE_HITCEIL or MOVE_HITLAND)) then
  begin
    Obj^.Vel.Y := 0;
    Obj^.Accel.Y := 0;
  end;
end;

function g_Obj_Collide(Obj1, Obj2: PObj): Boolean;
begin
  Result := g_Collide(Obj1^.X+Obj1^.Rect.X, Obj1^.Y+Obj1^.Rect.Y,
                      Obj1^.Rect.Width, Obj1^.Rect.Height,
                      Obj2^.X+Obj2^.Rect.X, Obj2^.Y+Obj2^.Rect.Y,
                      Obj2^.Rect.Width, Obj2^.Rect.Height);
end;

function g_Obj_Collide(X, Y: Integer; Width, Height: Word; Obj: PObj): Boolean;
begin
  Result := g_Collide(X, Y,
                      Width, Height,
                      Obj^.X+Obj^.Rect.X, Obj^.Y+Obj^.Rect.Y,
                      Obj^.Rect.Width, Obj^.Rect.Height);
end;

function g_Obj_CollidePoint(X, Y: Integer; Obj: PObj): Boolean;
begin
  Result := g_CollidePoint(X, Y, Obj^.X+Obj^.Rect.X, Obj^.Y+Obj^.Rect.Y,
                           Obj^.Rect.Width, Obj^.Rect.Height);
end;

procedure g_Obj_Push(Obj: PObj; VelX, VelY: Integer);
begin
  Obj^.Vel.X := Obj^.Vel.X + VelX;
  Obj^.Vel.Y := Obj^.Vel.Y + VelY;
end;

procedure g_Obj_PushA(Obj: PObj; Vel: Integer; Angle: SmallInt);
var
  s, c: Extended;

begin
  SinCos(DegToRad(-Angle), s, c);

  Obj^.Vel.X := Obj^.Vel.X + Round(Vel*c);
  Obj^.Vel.Y := Obj^.Vel.Y + Round(Vel*s);
end;

procedure g_Obj_SetSpeed(Obj: PObj; s: Integer);
var
  m, vx, vy: Integer;
begin
  vx := Obj^.Vel.X;
  vy := Obj^.Vel.Y;

  m := Max(Abs(vx), Abs(vy));
  if m = 0 then
    m := 1;

  Obj^.Vel.X := (vx*s) div m;
  Obj^.Vel.Y := (vy*s) div m;
end;

function z_dec(a, b: Integer): Integer;
begin
// ���������� a � 0 �� b ������:
  if Abs(a) < b then
    Result := 0
  else
    if a > 0 then
      Result := a - b
    else
      if a < 0 then
        Result := a + b
      else // a = 0
        Result := 0;
end;

function z_fdec(a, b: Double): Double;
begin
// ���������� a � 0.0 �� b ������:
  if Abs(a) < b then
    Result := 0.0
  else
    if a > 0.0 then
      Result := a - b
    else
      if a < 0.0 then
        Result := a + b
      else // a = 0.0
        Result := 0.0;
end;

end.
