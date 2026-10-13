#define MyAppName "INFRARED"
#define MyAppVersion "1.4.0"
[Setup]
AppId={{2AD54019-BC11-4541-9C03-98F88AC0DDFA}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=INFRARED
DefaultDirName={localappdata}\Programs\INFRARED
DefaultGroupName=INFRARED
PrivilegesRequired=lowest
OutputDir=build\installer
OutputBaseFilename=INFRARED-Windows-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\infrared.exe
[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
[Icons]
Name: "{autoprograms}\INFRARED"; Filename: "{app}\infrared.exe"
Name: "{autodesktop}\INFRARED"; Filename: "{app}\infrared.exe"
[Run]
Filename: "{app}\infrared.exe"; Description: "Abrir INFRARED"; Flags: nowait postinstall skipifsilent
