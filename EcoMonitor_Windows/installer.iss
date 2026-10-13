#define AppName "EcoMonitor"
#define AppVersion "1.0.0"
#define AppExeName "EcoMonitor.exe"
[Setup]
AppId={{70E32825-8292-471A-A395-EC92DBB41843}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} Desktop {#AppVersion}
DefaultDirName={localappdata}\Programs\EcoMonitor
DefaultGroupName=EcoMonitor
PrivilegesRequired=lowest
OutputDir=output
OutputBaseFilename=EcoMonitor_Windows_Instalador
Compression=lzma
SolidCompression=yes
SetupIconFile=src\assets\ecomonitor.ico
UninstallDisplayIcon={app}\EcoMonitor.exe
ArchitecturesAllowed=x64
WizardStyle=modern
DisableProgramGroupPage=yes
[Files]
Source: "dist\EcoMonitor.exe"; DestDir: "{app}"; Flags: ignoreversion
[Icons]
Name: "{autoprograms}\EcoMonitor"; Filename: "{app}\EcoMonitor.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\EcoMonitor"; Filename: "{app}\EcoMonitor.exe"; Tasks: desktopicon; WorkingDir: "{app}"
[Tasks]
Name: "desktopicon"; Description: "Criar atalho na area de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked
[Run]
Filename: "{app}\EcoMonitor.exe"; Description: "Abrir EcoMonitor"; Flags: nowait postinstall skipifsilent