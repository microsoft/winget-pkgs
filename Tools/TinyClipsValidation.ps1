[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $MsixPath,

    [Parameter(Mandatory)]
    [string] $OutputDirectory,

    [ValidateRange(20, 120)]
    [int] $WaitSeconds = 60,

    [switch] $StandardUser,

    [switch] $RunnerControl
)

$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Run this diagnostic only on a disposable GitHub-hosted runner.'
}
if ($RunnerControl -and -not $StandardUser) { throw 'RunnerControl is only valid for the worker mode.' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if ($StandardUser) {
    "Worker entered the script (PID $PID)." | Set-Content (Join-Path $OutputDirectory 'bootstrap.log')
}

Add-Type -TypeDefinition @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class TinyClipsLimitedProcess
{
    [StructLayout(LayoutKind.Sequential)]
    private struct SidAndAttributes { public IntPtr Sid; public uint Attributes; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfo
    {
        public uint Size;
        public string Reserved, Desktop, Title;
        public uint X, Y, XSize, YSize, XCountChars, YCountChars, FillAttribute, Flags;
        public ushort ShowWindow, ReservedSize;
        public IntPtr ReservedPointer, Input, Output, Error;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInformation
    {
        public IntPtr Process, Thread;
        public uint ProcessId, ThreadId;
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(IntPtr token, int kind, IntPtr data, uint size, out uint needed);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcessWithTokenW(IntPtr token, uint logonFlags, string application,
        StringBuilder commandLine, uint flags, IntPtr environment, string directory,
        ref StartupInfo startup, out ProcessInformation process);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);
    private static void Check(bool success, string operation)
    {
        if (!success)
        {
            int error = Marshal.GetLastWin32Error();
            throw new Win32Exception(error, operation + ": " + new Win32Exception(error).Message);
        }
    }

    public static uint IntegrityLevel()
    {
        IntPtr token = IntPtr.Zero, buffer = IntPtr.Zero;
        try
        {
            Check(OpenProcessToken(GetCurrentProcess(), 0x8, out token), "OpenProcessToken(current worker)");
            uint size;
            GetTokenInformation(token, 25, IntPtr.Zero, 0, out size);
            if (size == 0) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            buffer = Marshal.AllocHGlobal(checked((int)size));
            Check(GetTokenInformation(token, 25, buffer, size, out size), "GetTokenInformation(TokenIntegrityLevel)");
            var sid = Marshal.PtrToStructure<SidAndAttributes>(buffer).Sid;
            int count = Marshal.ReadByte(sid, 1);
            return unchecked((uint)Marshal.ReadInt32(sid, 8 + (count - 1) * 4));
        }
        finally
        {
            if (buffer != IntPtr.Zero) { Marshal.FreeHGlobal(buffer); }
            if (token != IntPtr.Zero) { CloseHandle(token); }
        }
    }

    public static Process Start(string executable, string arguments, string directory)
    {
        IntPtr original = IntPtr.Zero, limited = IntPtr.Zero, linked = IntPtr.Zero, environment = IntPtr.Zero;
        ProcessInformation process = default(ProcessInformation);
        try
        {
            Check(OpenProcessToken(GetCurrentProcess(), 0x8, out original), "OpenProcessToken(controller)");
            linked = Marshal.AllocHGlobal(IntPtr.Size);
            uint needed;
            Check(GetTokenInformation(original, 19, linked, checked((uint)IntPtr.Size), out needed), "GetTokenInformation(TokenLinkedToken)");
            limited = Marshal.ReadIntPtr(linked);
            var variables = new List<string>();
            foreach (DictionaryEntry variable in Environment.GetEnvironmentVariables())
            {
                variables.Add(variable.Key + "=" + variable.Value);
            }
            variables.Sort(StringComparer.OrdinalIgnoreCase);
            environment = Marshal.StringToHGlobalUni(string.Join("\0", variables) + "\0\0");
            var startup = new StartupInfo { Size = checked((uint)Marshal.SizeOf<StartupInfo>()), Flags = 1, ShowWindow = 0 };
            var commandLine = new StringBuilder("\"" + executable + "\" " + arguments);
            Check(CreateProcessWithTokenW(limited, 1, executable, commandLine, 0x00000410,
                environment, directory, ref startup, out process), "CreateProcessWithTokenW(non-admin worker)");
            return Process.GetProcessById(checked((int)process.ProcessId));
        }
        finally
        {
            if (process.Thread != IntPtr.Zero) { CloseHandle(process.Thread); }
            if (process.Process != IntPtr.Zero) { CloseHandle(process.Process); }
            if (environment != IntPtr.Zero) { Marshal.FreeHGlobal(environment); }
            if (linked != IntPtr.Zero) { Marshal.FreeHGlobal(linked); }
            if (limited != IntPtr.Zero) { CloseHandle(limited); }
            if (original != IntPtr.Zero) { CloseHandle(original); }
        }
    }
}
'@
if ($StandardUser) {
    'Native interop compiled.' | Add-Content (Join-Path $OutputDirectory 'bootstrap.log')
}

if (-not $StandardUser) {
    $root = 'C:\TinyClipsValidation'
    $process = $null
    $rootCreated = $false
    try {
        if (Test-Path $root) { throw "Refusing to reuse existing directory $root." }
        New-Item -ItemType Directory -Path $root | Out-Null
        $rootCreated = $true
        $workerOutput = Join-Path $root 'diagnostics'
        New-Item -ItemType Directory -Path $workerOutput | Out-Null
        Copy-Item $MsixPath (Join-Path $root 'package.msix')
        Copy-Item $PSCommandPath (Join-Path $root 'worker.ps1')
        $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        & icacls.exe $root /grant "*${userSid}:(OI)(CI)M" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to grant the validation user access to test files.' }

        $pwsh = (Get-Process -Id $PID).Path
        $arguments = "-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File `"$root\worker.ps1`" -StandardUser -MsixPath `"$root\package.msix`" -OutputDirectory `"$workerOutput`" -WaitSeconds $WaitSeconds"
        # Use Windows' existing unelevated token rather than constructing a synthetic logon.
        $process = [TinyClipsLimitedProcess]::Start($pwsh, $arguments, $root)
        $null = $process.Handle
        $readyDeadline = (Get-Date).AddSeconds(60)
        while (-not (Test-Path (Join-Path $workerOutput 'bootstrap.log')) -and -not $process.HasExited -and (Get-Date) -lt $readyDeadline) {
            Start-Sleep -Seconds 1
        }
        if (-not (Test-Path (Join-Path $workerOutput 'bootstrap.log'))) {
            throw 'The non-admin worker did not enter the script within 60 seconds.'
        }
        if (-not $process.WaitForExit(720000)) { throw 'Standard-user validation exceeded 12 minutes.' }
        if (-not (Test-Path (Join-Path $workerOutput 'results.json'))) {
            throw "Standard-user validation produced no results (exit code $($process.ExitCode))."
        }
        Get-Content (Join-Path $workerOutput 'results.json')
        if ($process.ExitCode -ne 0) { throw "Standard-user validation failed (exit code $($process.ExitCode))." }
    }
    catch {
        $_ | Out-String | Set-Content (Join-Path $OutputDirectory 'controller-error.txt')
        $workerResultsExist = $rootCreated -and (Test-Path "$root\diagnostics\results.json")
        if (-not $workerResultsExist) {
            ConvertTo-Json -InputObject @([pscustomobject]@{
                AccountMode = 'standard-user'
                Status = 'worker-unavailable'
                AppLaunchTestExecuted = $false
                Error = $_.ToString()
            }) -Depth 5 | Set-Content (Join-Path $OutputDirectory 'results.json')
        }
        throw
    }
    finally {
        if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
        if ($rootCreated -and (Test-Path "$root\diagnostics")) {
            Copy-Item "$root\diagnostics\*" $OutputDirectory -Force
        }
    }
    return
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin -and -not $RunnerControl) { throw 'Worker must run as a non-elevated standard user.' }
$integrity = [TinyClipsLimitedProcess]::IntegrityLevel()
if (-not $RunnerControl -and $integrity -ne 8192) { throw "Expected medium integrity, observed $integrity." }

$start = Get-Date
$results = [Collections.Generic.List[object]]::new()
$failure = $false
$mappedDrive = $false
$packageInstalled = $false
$ownedProcesses = [Collections.Generic.List[Diagnostics.Process]]::new()
$log = Join-Path $OutputDirectory 'worker.log'
Start-Transcript -Path $log | Out-Null

try {
    "Account mode: $(if ($RunnerControl) { 'runner-control' } else { 'standard-user' }); elevated: $isAdmin"
    "Integrity level: $integrity; standard-user mode uses the existing desktop account with its Windows UAC-linked token."
    "Process architecture: $([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)"
    "Session: $((Get-Process -Id $PID).SessionId); interactive: $([Environment]::UserInteractive)"
    "This is a reproduction approximation, not Microsoft's private validation harness."
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $workingDirectory = 'C:\TinyClipsValidation\cwd'
    New-Item -ItemType Directory -Path $workingDirectory -Force | Out-Null
    if (-not (Test-Path 'E:\')) {
        & subst.exe E: $workingDirectory
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path 'E:\')) { throw 'Unable to provide E: for the working-directory scenarios.' }
        $mappedDrive = $true
    }
    "E: drive: $(if ($mappedDrive) { 'user-scoped SUBST mapping' } else { 'existing runner volume' })"

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TinyClipsValidationWindow
{
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);

    [ComImport, Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IActivationManager
    {
        [PreserveSig] int ActivateApplication(
            [MarshalAs(UnmanagedType.LPWStr)] string appId,
            [MarshalAs(UnmanagedType.LPWStr)] string arguments,
            uint options, out uint processId);
    }

    public static uint Activate(string appId)
    {
        var type = Type.GetTypeFromCLSID(new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C"), true);
        var manager = (IActivationManager)Activator.CreateInstance(type);
        try
        {
            uint processId;
            Marshal.ThrowExceptionForHR(manager.ActivateApplication(appId, null, 2, out processId));
            return processId;
        }
        finally { Marshal.ReleaseComObject(manager); }
    }
}
'@

    foreach ($scenario in @(
        @{ Name = 'unrelated-directory'; Directory = $workingDirectory },
        @{ Name = 'e-root'; Directory = 'E:\' },
        @{ Name = 'e-drive-relative'; Directory = 'E:' },
        @{ Name = 'registered-activation-control'; Directory = $null }
    )) {
        $ownedProcesses.Clear()
        $scenarioStart = Get-Date
        try {
            if (Get-AppxPackage -Name Refractored.TinyClips) { throw 'Expected a fresh validation account without Tiny Clips installed.' }
            Add-AppxPackage -Path $MsixPath
            $packageInstalled = $true
            $package = Get-AppxPackage -Name Refractored.TinyClips
            if (-not $package -or $package.Version -ne '1.8.2.0') { throw 'The submitted Tiny Clips version did not register.' }
            "Scenario $($scenario.Name): $($package.PackageFullName); cwd=$($scenario.Directory)"

            $exe = Join-Path $package.InstallLocation 'TinyClips.App.exe'
            $launchMethod = if ($scenario.Directory) { 'ShellExecute' } else { 'registered-AUMID' }
            foreach ($launch in @('first', 'second')) {
                if ($scenario.Directory) {
                    $info = [Diagnostics.ProcessStartInfo]::new()
                    $info.FileName = $exe
                    $info.WorkingDirectory = $scenario.Directory
                    $info.UseShellExecute = $true
                    $process = [Diagnostics.Process]::Start($info)
                }
                else {
                    $appId = "$($package.PackageFamilyName)!App"
                    $activatedPid = [TinyClipsValidationWindow]::Activate($appId)
                    $process = Get-Process -Id $activatedPid
                }
                $null = $process.Handle
                $ownedProcesses.Add($process)
                "Launched $launch instance; PID $($process.Id)"
                Start-Sleep -Seconds 15
                $process.Refresh()
                if (-not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
                    [void][TinyClipsValidationWindow]::ShowWindow($process.MainWindowHandle, 5)
                    $foreground = [TinyClipsValidationWindow]::SetForegroundWindow($process.MainWindowHandle)
                    "Foreground request for $launch instance: $foreground"
                }
            }
            $deadline = (Get-Date).AddSeconds($WaitSeconds)
            while ((Get-Date) -lt $deadline) {
                Start-Sleep -Seconds 2
                if (@($ownedProcesses | Where-Object { -not $_.HasExited }).Count -eq 0) { break }
            }
            for ($index = 0; $index -lt $ownedProcesses.Count; $index++) {
                $process = $ownedProcesses[$index]
                $process.Refresh()
                $exited = $process.HasExited
                $code = if ($exited) { $process.ExitCode } else { $null }
                $status = if (-not $exited) { 'alive' } elseif ($index -eq 1 -and $code -eq 0) { 'clean-secondary-exit' } else { 'unexpected-exit' }
                if ($status -eq 'unexpected-exit') { $failure = $true }
                $results.Add([pscustomobject]@{
                    Scenario = $scenario.Name
                    WorkingDirectory = $scenario.Directory
                    AccountMode = if ($RunnerControl) { 'runner-control' } else { 'standard-user' }
                    LaunchMethod = $launchMethod
                    Launch = if ($index -eq 0) { 'first' } else { 'second' }
                    Status = $status
                    ExitCode = $code
                    ExitCodeHex = if ($exited) { '0x{0:X8}' -f $code } else { $null }
                    ObservedSeconds = [int]((Get-Date) - $scenarioStart).TotalSeconds
                    MappedEDrive = $mappedDrive
                })
            }
        }
        catch {
            $failure = $true
            $results.Add([pscustomobject]@{
                Scenario = $scenario.Name
                AccountMode = if ($RunnerControl) { 'runner-control' } else { 'standard-user' }
                Status = 'harness-or-install-error'
                Error = $_.ToString()
            })
            Write-Warning $_
        }
        finally {
            foreach ($process in $ownedProcesses) {
                if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
                $process.Dispose()
            }
            if ($packageInstalled) {
                $package = Get-AppxPackage -Name Refractored.TinyClips
                if ($package) {
                    foreach ($crashLog in @(
                        "$localAppData\TinyClips\Logs\crash.log",
                        "$localAppData\Packages\$($package.PackageFamilyName)\LocalCache\Local\TinyClips\Logs\crash.log"
                    )) {
                        if (Test-Path $crashLog) {
                            Get-Content $crashLog | Add-Content (Join-Path $OutputDirectory "$($scenario.Name)-crash.log")
                        }
                    }
                    Remove-AppxPackage -Package $package.PackageFullName
                }
                $packageInstalled = $false
            }
        }
    }
}
catch {
    $failure = $true
    $results.Add([pscustomobject]@{ Status = 'harness-error'; Error = $_.ToString() })
    Write-Warning $_
}
finally {
    $eventErrors = @()
    $events = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $start } `
        -ErrorAction SilentlyContinue -ErrorVariable eventErrors
    if ($eventErrors) {
        $eventErrors | Out-String | Set-Content (Join-Path $OutputDirectory 'event-read-status.txt')
    }
    $events | Where-Object {
        $_.ProviderName -in @('.NET Runtime', 'Application Error', 'Windows Error Reporting') -and
        $_.Message -match 'TinyClips|Tiny Clips'
    } | Select-Object TimeCreated, ProviderName, Id, Message |
        Format-List | Out-String -Width 240 | Set-Content (Join-Path $OutputDirectory 'application-events.txt')
    ConvertTo-Json -InputObject $results.ToArray() -Depth 5 | Set-Content (Join-Path $OutputDirectory 'results.json')
    if ($mappedDrive) {
        & subst.exe E: /D
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Unable to remove the test E: mapping.' }
    }
    Stop-Transcript | Out-Null
}

if ($failure) { exit 1 }
