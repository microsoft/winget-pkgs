**Build-MinWin11.ps1**

Minimal Windows 11 VHDX builder script.

- **Script:** [Tools/Build-MinWin11.ps1](Tools/Build-MinWin11.ps1)

**Summary:**
- Creates a dynamically sized VHDX, initializes GPT partitions (EFI + OS), applies a Windows 11 image from a mounted ISO, configures basic UEFI boot, optionally services the offline image (removes features / provisioned apps), and optionally creates a Hyper-V VM using the VHDX.

**Prerequisites:**
- **Run as Administrator:** The script must be executed from an elevated PowerShell session.
- **PowerShell version:** Requires PowerShell 5.1 (Windows PowerShell) due to use of built-in cmdlets and DISM commands.
- **Windows 11 ISO downloaded and mounted:** Mount the Windows 11 ISO (right-click -> Mount, or use `Mount-DiskImage`) and note the assigned drive letter (e.g., `D:`). Download from the official Microsoft page: https://www.microsoft.com/software-download/windows11
- **DISM and bcdboot:** The script uses the built-in `dism` and `bcdboot` utilities.
- **Hyper-V (optional):** If the Hyper-V module is available and you want a VM created automatically, enable Hyper-V beforehand and run from an Admin session.

**Important note:** The script includes an "aggressive" list of features and provisioned app removals. Review the script before running if you need specific Windows features or provisioned packages preserved.

**Parameters:**
- **`-IsoDrive`**: (string) Drive letter where the Windows 11 ISO is mounted. Example: `D:`. (Required)
- **`-ImageIndex`**: (int) Index of the Windows 11 image within the `install.wim` or `install.esd`. Use DISM to check the available indexes. (Required)
- **`-VhdPath`**: (string) Full path to create the VHDX file. Example: `C:\MinWin11.vhdx`. (Required)
- **`-VhdSizeGB`**: (int) Size of the VHDX in GB (dynamic disk). Default: `25`.
- **`-VmName`**: (string) Name of the Hyper-V VM to create (optional). Default: `MinWin11`.

**How to determine image index:**
- Use DISM to list images in the WIM/ESD on the mounted ISO. Replace `D:` with your ISO drive letter:

```powershell
# For WIM
dism /Get-WimInfo /WimFile:D:\sources\install.wim

# For ESD (DISM supports reading ESD similarly)
dism /Get-ImageInfo /ImageFile:D:\sources\install.esd
```

Look for the `Index :` value you want to apply (for example, 1 for the first edition).

**Basic usage examples:**

Open an elevated PowerShell prompt and run (example values shown):

```powershell
# From the Tools folder
cd <path-to-repo>\Tools

# Basic: create a 25GB dynamic VHDX from the image at D:, using index 1
.\Build-MinWin11.ps1 -IsoDrive D: -ImageIndex 1 -VhdPath C:\MinWin11.vhdx

# With custom size and VM name
.\Build-MinWin11.ps1 -IsoDrive D: -ImageIndex 2 -VhdPath C:\MinWin11.vhdx -VhdSizeGB 40 -VmName "MyMinWin11"
```

**What the script does (high level):**
- Locates `install.wim` or `install.esd` on the mounted ISO at `\sources`.
- Creates a dynamic VHDX at the path provided (`-VhdPath`) and mounts it.
- Initializes the disk as GPT and creates a 100MB EFI partition and the remaining OS partition.
- Formats the partitions (EFI = FAT32, OS = NTFS).
- Applies the Windows image to the OS partition using `dism /Apply-Image`.
- Creates UEFI boot files with `bcdboot`.
- Optionally mounts an offline copy of the image for servicing and removes a predefined list of optional features and provisioned appx packages (see script for the removal list).
- Runs component-store cleanup (`/StartComponentCleanup /ResetBase`) to reduce size.
- Dismounts VHD and optionally creates a Hyper-V VM named `-VmName` if the Hyper-V cmdlets are present.

**Output:**
- A VHDX file at the path specified by `-VhdPath` (e.g., `C:\MinWin11.vhdx`).
- If Hyper-V is available and `-VmName` does not exist, a new Gen 2 VM is created and attached to the VHDX.

**Warnings & tips:**
- The script will throw an error if it cannot locate `install.wim` or `install.esd` in the ISO `sources` folder.
- Review and edit the features/provisioned-app removal lists in the script before running in production environments — the defaults are aggressive and intended for minimal builds.
- If you prefer to inspect the VHD before dismounting, modify the script or run the VHD mounting steps manually.
- Ensure sufficient free space on the volume where `-VhdPath` is located.

**Troubleshooting:**
- If the ISO is not mounted as a drive letter, use `Mount-DiskImage -ImagePath "C:\path\to\Win11.iso"` and then run `Get-Volume` or check Explorer to find the assigned drive letter.
- If `dism /Apply-Image` fails, verify the `-ImageIndex` value, and confirm whether the image file is `install.wim` or `install.esd`.
- If Hyper-V VM creation fails, verify the `Hyper-V` Windows feature is enabled and that you are running elevated PowerShell.

**Related files:**
- Script source: [Tools/Build-MinWin11.ps1](Tools/Build-MinWin11.ps1)
- Example sandbox/test reference: [doc/tools/SandboxTest.md](doc/tools/SandboxTest.md)

---

If you'd like, I can update the script's top-of-file comment block with a condensed usage summary or add example commands to the repository README.
