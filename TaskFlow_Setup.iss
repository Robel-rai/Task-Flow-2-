; TaskFlow Inno Setup Script
; Build with Inno Setup 6.3+ (https://jrsoftware.org/isinfo.php)
;
; Prerequisites:
;   1. Run: flutter build windows
;   2. Ensure redist/ contains the VC++ runtime DLLs (vcruntime140.dll,
;      vcruntime140_1.dll, msvcp140.dll, msvcp140_1.dll, msvcp140_2.dll).
;      They are copied from C:\Windows\System32 on the build machine and
;      installed next to the exe so target PCs need no runtime install.
;      Refresh them if you upgrade the Flutter/VS toolchain.
;   3. Open this file in Inno Setup Compiler
;   4. Click Build → Compile (or press Ctrl+F9)
;
; Output: install_output/Installer_TaskFlow2.exe

#define MyAppName "TaskFlow"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "Robel"
#define MyAppURL "https://github.com/Robel-rai/Task-Flow-2-"
#define MyAppExeName "taskflow.exe"

; Path to the Flutter release build output
#define FlutterBuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
; Per-user install location so the app directory is writable — the
; release database lives in {app}\DB next to the exe. {autopf} would
; allow an elevated run to land in Program Files, which is read-only.
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=install_output
OutputBaseFilename=Installer_TaskFlow2
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
PrivilegesRequired=lowest
SetupLogging=yes

; Installer exe icon (the .ico shown in Windows Explorer)
SetupIconFile=windows\runner\resources\main_app_icon.ico

; Installer wizard images (custom app icon)
WizardImageFile=assets\icon\wizard.bmp
WizardSmallImageFile=assets\icon\app_icon.png

; Uninstaller
UninstallDisplayName={#MyAppName} {#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1

[Files]
; Main application files from the Flutter release build
Source: "{#FlutterBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ 2015-2022 runtime DLLs, installed next to the exe so the app
; runs on machines without the VC++ redistributable (the DLLs ship with the
; installer instead of requiring a system-wide runtime install).
Source: "redist\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "redist\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "redist\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "redist\msvcp140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "redist\msvcp140_2.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start Menu shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

; Desktop shortcut (optional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; Quick Launch shortcut (optional, legacy Windows)
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Launch the app after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

; NOTE: no [UninstallDelete] section on purpose. The uninstaller removes
; the files Setup installed but must NOT wipe {app}\DB, which holds the
; user's task database. Leftover files stay in the folder after uninstall.
