#ifndef SourceDir
  #define SourceDir "..\client\build\windows\x64\runner\Release"
#endif
#ifndef ProjectRoot
  #define ProjectRoot ".."
#endif

[Setup]
AppId={{B3B0E0E7-7E06-4B76-8D55-2B0B2ACD6A9C}
AppName=Waste AI
AppVersion=0.1.0
AppPublisher=Waste AI
AppComments=Requires Python 3 on PATH for the companion browser launcher.
DefaultDirName={localappdata}\Programs\Waste AI
DefaultGroupName=Waste AI
OutputDir={#ProjectRoot}\dist
OutputBaseFilename=Waste-AI-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
UninstallDisplayName=Waste AI

[Files]
; Native Flutter desktop executable and its generated runtime files.
Source: "{#SourceDir}\*"; DestDir: "{app}\client"; Flags: recursesubdirs createallsubdirs ignoreversion
; The browser preview is served by companion.server from this exact location.
Source: "{#ProjectRoot}\client\web-preview\index.html"; DestDir: "{app}\client\web-preview"; Flags: ignoreversion
; Explicit allowlist: do not package tests, caches, logs, credentials, or other Python files.
Source: "{#ProjectRoot}\companion\__init__.py"; DestDir: "{app}\companion"; Flags: ignoreversion
Source: "{#ProjectRoot}\companion\local_tools.py"; DestDir: "{app}\companion"; Flags: ignoreversion
Source: "{#ProjectRoot}\companion\server.py"; DestDir: "{app}\companion"; Flags: ignoreversion
Source: "{#ProjectRoot}\launch.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectRoot}\Start-Waste.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectRoot}\packaging\README.md"; DestDir: "{app}\packaging"; Flags: ignoreversion

[Icons]
Name: "{userprograms}\Waste AI"; Filename: "{app}\client\waste.exe"; WorkingDir: "{app}\client"
Name: "{userprograms}\Waste AI Companion (browser)"; Filename: "{app}\Start-Waste.cmd"; WorkingDir: "{app}"
Name: "{userdesktop}\Waste AI"; Filename: "{app}\client\waste.exe"; WorkingDir: "{app}\client"
Name: "{userdesktop}\Waste AI Companion (browser)"; Filename: "{app}\Start-Waste.cmd"; WorkingDir: "{app}"

[Run]
Filename: "{app}\packaging\README.md"; Description: "Open the Waste AI packaging notes"; Flags: postinstall shellexec skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  if Exec(ExpandConstant('{cmd}'), '/c python -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >nul 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0) then
    Result := True
  else begin
    MsgBox('Python 3 must be installed and available on PATH for the companion browser launcher.', mbError, MB_OK);
    Result := False;
  end;
end;
