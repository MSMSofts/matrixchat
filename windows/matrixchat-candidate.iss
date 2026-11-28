; MatrixChat candidate installer, derived from the upstream installer.
; Build with: scripts/package-windows.ps1 -MatrixChatCandidate

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef BuildDir
  #define BuildDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
; Never change the AppId! Inno Setup uses it to detect an existing
; installation, so that a new installer updates it in place.
AppId={{E74F1609-B584-4D4A-A9E8-9D25CF917304}
AppName=MatrixChat Candidate
AppVersion={#AppVersion}
AppVerName=MatrixChat Candidate {#AppVersion}
AppPublisher=MatrixChat contributors
AppPublisherURL=https://github.com/MSMSofts/matrixchat
AppSupportURL=https://github.com/MSMSofts/matrixchat/issues
AppUpdatesURL=https://github.com/MSMSofts/matrixchat/releases
VersionInfoVersion={#AppVersion}
; Per-user installation into %LOCALAPPDATA%\Programs, so that neither the
; installation nor updates require admin rights.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\MatrixChat Candidate
DisableProgramGroupPage=yes
UsePreviousAppDir=no
DisableDirPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\fluffychat.exe
LicenseFile=..\LICENSE
OutputDir=..\build\windows\installer
OutputBaseFilename=matrixchat-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "polish"; MessagesFile: "compiler:Languages\Polish.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "ukrainian"; MessagesFile: "compiler:Languages\Ukrainian.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\MatrixChat Candidate"; Filename: "{app}\fluffychat.exe"
Name: "{autodesktop}\MatrixChat Candidate"; Filename: "{app}\fluffychat.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\fluffychat.exe"; Description: "{cm:LaunchProgram,MatrixChat Candidate}"; Flags: nowait postinstall skipifsilent
