unit FJunction;

interface

type
  TReparsePointType = (
    slUnknown,
    slJunction,
    slMountPoint,
    slSymLink,
    slHSM,
    slSIS,
    slDFS
    );

const
  SReparsePointType: array[TReparsePointType] of PChar = (
    'Unknown point type',
    'Junction',
    'Mount Point',
    'Symbolic Link',
    'Hierarchical Storage Management point',
    'Single Instance Store point',
    'Distributed File System point'
    );

function FCreateSymlink(const fnLink, fnTarget: WideString): boolean;
function FGetSymlinkInfo(const fn: WideString; var Target: WideString; var LinkType: TReparsePointType): boolean;
function FDeleteSymlink(const fn: WideString): boolean;
function FDriveSupportsSymlinks(const fn: WideString): boolean;

implementation

uses Windows, FProc;

//-------------------------------------------------------------
const
  MAX_REPARSE_SIZE = 17000;
  MAX_NAME_LENGTH = 1024;

  FILE_DEVICE_FILE_SYSTEM = $0009;

  METHOD_BUFFERED   = 0;
  METHOD_IN_DIRECT  = 1;
  METHOD_OUT_DIRECT = 2;
  METHOD_NEITHER    = 3;

  FILE_ANY_ACCESS = 0;
  FILE_READ_DATA  = 1;
  FILE_WRITE_DATA = 2;

  //#define FSCTL_SET_REPARSE_POINT         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 41, METHOD_BUFFERED, FILE_WRITE_DATA)
  //#define FSCTL_GET_REPARSE_POINT         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 42, METHOD_BUFFERED, FILE_ANY_ACCESS)
  //#define FSCTL_DELETE_REPARSE_POINT      CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 43, METHOD_BUFFERED, FILE_WRITE_DATA)
  FSCTL_SET_REPARSE_POINT    = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (41 shl 2) or (METHOD_BUFFERED);
  FSCTL_GET_REPARSE_POINT    = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (42 shl 2) or (METHOD_BUFFERED);
  FSCTL_DELETE_REPARSE_POINT = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (43 shl 2) or (METHOD_BUFFERED);

  FILE_FLAG_OPEN_REPARSE_POINT = $00200000;

  IO_REPARSE_TAG_RESERVED_ZERO  = $000000000;
  IO_REPARSE_TAG_SYMBOLIC_LINK  = IO_REPARSE_TAG_RESERVED_ZERO;
  IO_REPARSE_TAG_RESERVED_ONE   = $000000001;
  IO_REPARSE_TAG_RESERVED_RANGE = $000000001;
  IO_REPARSE_TAG_VALID_VALUES   = $0E000FFFF;
  IO_REPARSE_TAG_HSM            = $0C0000004;
  IO_REPARSE_TAG_NSS            = $080000005;
  IO_REPARSE_TAG_NSSRECOVER     = $080000006;
  IO_REPARSE_TAG_SIS            = $080000007;
  IO_REPARSE_TAG_DFS            = $080000008;
  IO_REPARSE_TAG_MOUNT_POINT    = $0A0000003;

  REPARSE_MOUNTPOINT_HEADER_SIZE = 8;

  FILE_SUPPORTS_REPARSE_POINTS = $00000080;

type
  REPARSE_MOUNTPOINT_DATA_BUFFER = packed record
    ReparseTag: DWORD;
    ReparseDataLength: DWORD;
    Reserved: Word;
    ReparseTargetLength: Word;
    ReparseTargetMaximumLength: Word;
    Reserved1: Word;
    ReparseTarget: array[0..0] of WideChar;
  end;
  TReparseMountPointDataBuffer = REPARSE_MOUNTPOINT_DATA_BUFFER;
  PReparseMountPointDataBuffer = ^TReparseMountPointDataBuffer;

  REPARSE_DATA_BUFFER = packed record
    ReparseTag: DWORD;
    ReparseDataLength: Word;
    Reserved: Word;
    SubstituteNameOffset: Word;
    SubstituteNameLength: Word;
    PrintNameOffset: Word;
    PrintNameLength: Word;
    PathBuffer: array[0..0] of WideChar;
  end;
  TReparseDataBuffer = REPARSE_DATA_BUFFER;
  PReparseDataBuffer = ^TReparseDataBuffer;

//-------------------------------------------------------------
procedure Log(const msg: string);
begin
  //Writeln(msg);
end;

//-------------------------------------------------------------
const
  Prefix: WideString = '\??\';

function FCreateSymlink(const fnLink, fnTarget: WideString): boolean;
var
  h: THandle;
  Buffer: PReparseMountPointDataBuffer;
  BufSize: integer;
  TargetName: WideString;
  BytesRead: DWORD;
begin
  Result:= false;
  if IsFileExist(fnLink) then
    begin
    Log('Target already exists');
    Exit
    end;
  if not CreateDirectoryW(PWChar(fnLink), nil) then
    begin
    Log('CreateDirectoryW failed');
    Exit
    end;

  h:= CreateFileW(PWChar(fnLink), GENERIC_WRITE, 0, nil, OPEN_EXISTING,
    FILE_FLAG_OPEN_REPARSE_POINT or FILE_FLAG_BACKUP_SEMANTICS, 0);
  if h=INVALID_HANDLE_VALUE then
    begin
    Log('CreateFileW failed');
    RemoveDirectoryW(PWChar(fnLink));
    Exit
    end;

  TargetName:= Prefix+fnTarget;
  BufSize:= (Length(Prefix)+Length(fnTarget)+1)*2+REPARSE_MOUNTPOINT_HEADER_SIZE+12;
  GetMem(Buffer, BufSize);
  FillChar(Buffer^, BufSize, 0);

  with Buffer^ do
    begin
    Move(TargetName[1], ReparseTarget, (Length(TargetName)+1)*2);
    ReparseTag:= IO_REPARSE_TAG_MOUNT_POINT;
    ReparseTargetLength:= Length(TargetName)*2;
    ReparseTargetMaximumLength:= ReparseTargetLength+2;
    ReparseDataLength:= ReparseTargetLength+12;
    end;

  {
  with Buffer^ do
    begin
    Writeln('Reparse info:');
    Writeln('ReparseTargetLength: ', ReparseTargetLength);
    Writeln('ReparseTarget: "', string(ReparseTarget), '"');
    end;
    }

  BytesRead:= 0;
  Result:= DeviceIoControl(h, FSCTL_SET_REPARSE_POINT,
    Buffer, Buffer^.ReparseDataLength+REPARSE_MOUNTPOINT_HEADER_SIZE, nil, 0,
    BytesRead, nil);
  if not Result then
    begin
    Log('DeviceIoControl failed');
    Sleep(500); //for RemoveDirectoryW to work
    RemoveDirectoryW(PWChar(fnLink));
    end;

  FreeMem(Buffer);
  CloseHandle(h);
end;

//-------------------------------------------------------------
function FGetSymlinkInfo(const fn: WideString; var Target: WideString; var LinkType: TReparsePointType): boolean;
var
  attr: DWORD;
  h: THandle;
  reparseBuffer: array[0..MAX_REPARSE_SIZE-1] of char;
  reparseInfo: PReparseDataBuffer;
  reparseData: pointer;
  //reparseData1,
  reparseData2: PWChar;
  //name1,
  name2: array[0..MAX_NAME_LENGTH-1] of WideChar;
  returnedLength: DWORD;
  control: boolean;
begin
  Result:= false;
  Target:= '';
  LinkType:= slUnknown;

  attr:= GetFileAttributesW(PWChar(fn));
  if (attr and FILE_ATTRIBUTE_REPARSE_POINT)=0 then Exit;

  if (attr and FILE_ATTRIBUTE_DIRECTORY)<>0 then
    h:= CreateFileW(PWChar(fn), 0,
      FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
      OPEN_EXISTING, 
      FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OPEN_REPARSE_POINT, 0)
  else
    h:= CreateFileW(PWChar(fn), 0,
      FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
      OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT, 0);

  if h=INVALID_HANDLE_VALUE then
    begin
    Log('CreateFileW failed');
    Exit
    end;

  reparseInfo:= @reparseBuffer;
  control:= DeviceIoControl(h, FSCTL_GET_REPARSE_POINT,
    nil, 0, reparseInfo, SizeOf(reparseBuffer),
    returnedLength, nil);
  CloseHandle(h);
  if not control then
    begin
    Log('DeviceIoControl failed');
    Exit
    end;

  case reparseInfo^.ReparseTag of
    IO_REPARSE_TAG_MOUNT_POINT:
      begin
      reparseData:= @reparseInfo.PathBuffer;

      {
      FillChar(name1, SizeOf(name1), 0);
      reparseData1:= pointer(integer(reparseData)+reparseInfo.PrintNameOffset);
      lstrcpynW(name1, reparseData1, reparseInfo.PrintNameLength);
      }

      FillChar(name2, SizeOf(name2), 0);
      reparseData2:= pointer(integer(reparseData)+reparseInfo.SubstituteNameOffset);
      lstrcpynW(name2, reparseData2, reparseInfo.SubstituteNameLength);

      Target:= name2;
      if Pos(Prefix, Target)=1 then
        Delete(Target, 1, Length(Prefix));

      if Pos(':', Target)>0
        then LinkType:= slJunction
        else LinkType:= slMountPoint;

      Result:= true;
      end;

    IO_REPARSE_TAG_SYMBOLIC_LINK or $80000000:
      begin
      reparseData:= @reparseInfo.PathBuffer;

      {
      FillChar(name1, SizeOf(name1), 0);
      reparseData1:= pointer(integer(reparseData)+reparseInfo.PrintNameOffset);
      lstrcpynW(name1, reparseData1, reparseInfo.PrintNameLength);
      }

      FillChar(name2, SizeOf(name2), 0);
      reparseData2:= pointer(integer(reparseData)+reparseInfo.SubstituteNameOffset);
      lstrcpynW(name2, reparseData2, reparseInfo.SubstituteNameLength);

      Target:= name2;
      LinkType:= slSymLink;
      Result:= true;
      end;

    IO_REPARSE_TAG_HSM:
      begin
      LinkType:= slHSM;
      Result:= true;
      end;

    IO_REPARSE_TAG_SIS:
      begin
      LinkType:= slSIS;
      Result:= true;
      end;

    IO_REPARSE_TAG_DFS:
      begin
      LinkType:= slDFS;
      Result:= true;
      end;
  end;
end;

//-------------------------------------------------------------
function FDeleteSymlink(const fn: WideString): boolean;
begin
  Result:= RemoveDirectoryW(PWChar(fn));
end;

//-------------------------------------------------------------
function FDriveSupportsSymlinks(const fn: WideString): boolean;
var
  disk: char;
  buf1, buf2: array[0..50] of char;
  Serial, NameLen, Flags: DWORD;
begin
  Result:= false;
  if (fn='') or (Pos(':\', fn)<>2) then Exit;
  disk:= char(fn[1]);
  FillChar(buf1, SizeOf(buf1), 0);
  FillChar(buf2, SizeOf(buf2), 0);
  if GetVolumeInformation(PChar(disk+':\'), @buf1, SizeOf(buf1),
    @Serial, NameLen, Flags, @buf2, SizeOf(buf2)) then
    Result:= (Flags and FILE_SUPPORTS_REPARSE_POINTS)<>0;
end;



end.
