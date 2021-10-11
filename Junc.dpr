//====================================================================
// Junction creation and listing utility, based on Junction.c source
// by Mark Russinovich, http://www.sysinternals.com. Thanks Mark!
//
// Note: targets of some rare reparse point types are not recognized,
// as in Mark's source.
//
// (C) Alexey Torgashin, http://alextpp.narod.ru, atorg@yandex.ru
// 18.02.06 - initial version
//====================================================================

{$apptype console}

uses Windows, SysUtils, FProc, FJunction;

//-------------------------------------------------------------
function TestDirName(const fn: WideString; var fnOut: WideString): boolean;
begin
  Result:= FFullName(fn, fnOut) and IsDirExist(fnOut);
  if not Result then
    Writeln('Invalid name specified');
end;

//-------------------------------------------------------------
procedure FShowSymlinks(const dir: WideString);
var
  h: THandle;
  fd: TWin32FindDataW;
  fn, Target: WideString;
  TargetType: TReparsePointType;
  n: integer;
begin
  n:= 0;
  h:= FindFirstFileW(PWChar(dir+'\*.*'), fd);
  if h<>INVALID_HANDLE_VALUE then
  repeat
    fn:= dir+'\'+fd.cFileName;
    if (fd.dwFileAttributes and FILE_ATTRIBUTE_REPARSE_POINT)<>0 then
      begin
      if FGetSymlinkInfo(fn, Target, TargetType) then
        Writeln(
          SReparsePointType[TargetType], ': ',
          ToOEM(string(fn)), ' -> ', ToOEM(string(Target)))
      else
        Writeln(
          SReparsePointType[slUnknown], ': ',
          ToOEM(string(fn)));
      Inc(n);
      end;
  until not FindNextFileW(h, fd);
  Windows.FindClose(h);
  Writeln('Reparse points found: ', n);
end;

//-------------------------------------------------------------
const
  CR = #13#10;
var
  fnDir, fnDirFull,
  fnLink, fnLinkFull: WideString;
begin
  //Print help
  if ParamCount=0 then
    begin
    Writeln(
      'Junction creation and listing utility V1.0 (C) 2006 Alexey Torgashin'+CR+
      'Usage:'+CR+
      'Junc.exe <Junction> <Dir>  - Create junction to directory'+CR+
      'Junc.exe -d <Junction>     - Delete junction'+CR+
      'Junc.exe <Dir>             - Show junctions in directory ("." is allowed)');
    Exit
    end;

  //Don't run under Win9x, junction API is supported only under Win2K/XP
  if not IsNT then
    begin
    Writeln('This program cannot be used under Windows 9x');
    Exit
    end;

  //Show junctions
  if ParamCount=1 then
    begin
    fnDir:= ParamStr(1);
    Writeln('Directory: ', ToOEM(string(fnDir)));
    //Do not get full name for fnDir, it may not work for "."
    FShowSymlinks(fnDir);
    Exit
    end;

  //Delete junction
  if UpperCase(ParamStr(1))='-D' then
    begin
    fnLink:= ParamStr(2);
    Writeln('Junction: ', ToOEM(string(fnLink)));
    if not TestDirName(fnLink, fnLinkFull) then Exit;
    if FDeleteSymlink(fnLinkFull)
      then Writeln('Junction deleted')
      else Writeln('Cannot delete junction');
    Exit
    end;

  //Create new junction
  fnLink:= ParamStr(1);
  fnDir:= ParamStr(2);

  if not FFullName(fnLink, fnLinkFull) then
    begin
    Writeln('Invalid junction name specified');
    Exit
    end;
  if not TestDirName(fnDir, fnDirFull) then
    Exit;
  //Test target drive for "Reparse points supported" flag
  if not FDriveSupportsSymlinks(fnLinkFull) then
    begin
    Delete(fnLinkFull, Pos('\', fnLinkFull), MaxInt);
    Writeln('Junctions are not allowed on drive ', UpperCase(string(fnLinkFull)));
    Exit
    end;

  if FCreateSymlink(fnLinkFull, fnDirFull)
    then Writeln('Junction created: ', ToOEM(string(fnLinkFull)), ' -> ', ToOEM(string(fnDirFull)))
    else Writeln('Cannot create junction');
end.
