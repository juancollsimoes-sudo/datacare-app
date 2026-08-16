; installer.iss
#ifndef MyAppVersion
#define MyAppVersion "0.1.0"
#endif

[Setup]
AppName=DataCare
AppVersion={#MyAppVersion}
AppPublisher=DataCare
DefaultDirName={autopf}\DataCare
DefaultGroupName=DataCare
OutputDir=..\build\installer
OutputBaseFilename=DataCare-Windows-Setup-v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\datacare.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DataCare"; Filename: "{app}\datacare.exe"
Name: "{group}\{cm:UninstallProgram,DataCare}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\DataCare"; Filename: "{app}\datacare.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\datacare.exe"; Description: "{cm:LaunchProgram,DataCare}"; Flags: nowait postinstall skipifsilent
