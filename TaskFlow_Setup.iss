; TaskFlow Inno Setup Script
; Build with Inno Setup 6.3+ (https://jrsoftware.org/isinfo.php)
;
; Prerequisites:
;   1. Run: flutter build windows
;   2. Open this file in Inno Setup Compiler
;   3. Click Build → Compile (or press Ctrl+F9)
;
; Output: install_output/TaskFlow_Setup_v2.0.0.exe

#define MyAppName "TaskFlow"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "Yared"
#define MyAppURL "https://github.com/your-username/taskflow"
#define MyAppExeName "taskflow.exe"

; Path to the Flutter release build output
#define FlutterBuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=install_output
OutputBaseFilename=TaskFlow_Setup_v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
SetupLogging=yes

; Appearance
WizardImageFile=assets\icon\app_icon.bmp
WizardSmallImageFile=assets\icon\app_icon.bmp

; Uninstaller
UninstallDisplayName={#MyAppName} {#MyAppVersion}
UninstallDisplaySize=0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1

[Files]
; Main application files from the Flutter release build
Source: "{#FlutterBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

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

[UninstallDelete]
; Clean up any files the app may have created in the install directory
Type: filesandordirs; Name: "{app}"

[Code]
// Check if the app is currently running before installing/uninstalling
function IsAppRunning(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('tasklist', '/FI "IMAGENAME eq {#MyAppExeName}" /NH', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := (Pos('{#MyAppExeName}', SysErrorMessage(ResultCode)) > 0);
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Ensure the install directory exists
    ForceDirectories(ExpandConstant('{app}'));
  end;
end;
