unit FProc;

interface

uses Windows;

function IsFileExist(const fn: WideString): boolean; overload;
function IsFileExist(const fn: WideString; var IsDir: boolean): boolean; overload;
function IsDirExist(const fn: WideString): boolean;
function FFullName(const fn: WideString; var fnOut: WideString): boolean;

function ToOEM(const s: string): string;
function ToANSI(const s: string): string;

var
  IsNT: boolean;

const
  FILE_ATTRIBUTE_DEVICE               = $00000040;
  FILE_ATTRIBUTE_SPARSE_FILE          = $00000200;
  FILE_ATTRIBUTE_REPARSE_POINT        = $00000400;
  FILE_ATTRIBUTE_OFFLINE              = $00001000;
  FILE_ATTRIBUTE_NOT_CONTENT_INDEXED  = $00002000;
  FILE_ATTRIBUTE_ENCRYPTED            = $00004000;

implementation

//----------------------------------------------
function IsFileExist(const fn: WideString; var IsDir: boolean): boolean;
var
  h: THandle;
  fdA: TWin32FindDataA;
  fdW: TWin32FindDataW;
begin
  IsDir:= false;
  if fn='' then begin Result:= false; Exit end;
  if IsNT then
    begin
    h:= FindFirstFileW(PWChar(fn), fdW);
    Result:= h<>INVALID_HANDLE_VALUE;
    if Result then
      begin
      IsDir:= (fdW.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY)<>0;
      Windows.FindClose(h);
      end;
    end
  else
    begin
    h:= FindFirstFileA(PChar(string(fn)), fdA);
    Result:= h<>INVALID_HANDLE_VALUE;
    if Result then
      begin
      IsDir:= (fdA.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY)<>0;
      Windows.FindClose(h);
      end;
    end;
end;

//----------------------------------------------
function IsFileExist(const fn: WideString): boolean;
var
  IsDir: boolean;
begin
  Result:= IsFileExist(fn, IsDir);
end;

function IsDirExist(const fn: WideString): boolean;
var
  IsDir: boolean;
begin
  Result:= IsFileExist(fn, IsDir) and IsDir;
end;

//----------------------------------------------
function FFullName(const fn: WideString; var fnOut: WideString): boolean;
var
  bufA: array[0..MAX_PATH-1] of char;
  bufW: array[0..MAX_PATH-1] of WideChar;
  partA: PChar;
  partW: PWChar;
begin
  fnOut:= '';
  if IsNT then
    begin
    Result:= GetFullPathNameW(PWChar(fn), SizeOf(bufW) div 2, bufW, partW)<>0;
    if Result then fnOut:= bufW;
    end
  else
    begin
    Result:= GetFullPathNameA(PChar(string(fn)), SizeOf(bufA), bufA, partA)<>0;
    if Result then fnOut:= string(bufA);
    end;
end;

//----------------------------------------------
function ToOEM(const s: string): string;
begin
  SetLength(Result, Length(s));
  CharToOemBuff(PChar(s), PChar(Result), Length(s));
end;

function ToANSI(const s: string): string;
begin
  SetLength(Result, Length(s));
  OemToCharBuff(PChar(s), PChar(Result), Length(s));
end;

//----------------------------------------------

var
  vi: TOsVersionInfo;

initialization
  vi.dwOSVersionInfoSize:= SizeOf(vi);
  GetVersionEx(vi);
  IsNT:= vi.dwPlatformId=VER_PLATFORM_WIN32_NT;

finalization

end.
