# Using Build-MinWin11.ps1

The [Build-MinWinVHD.ps1](Tools/Build-MinWinVHD.ps1) script creates a new `V`irtual `H`ard `D`isk (VHD) using a mounted Windows ISO for use with a virtual machine. This image will have as few dependencies and apps enabled as possible, to provide the best approximation of the images uses by the validation pipelines. Although this is not the same image, it should be close enough to use for testing manifests for those who are unable to use Windows Sandbox and [SandboxTest.ps1](doc/tools/SandboxTest.ps1).

## Summary

This script creates a dynamically sized VHDX, initializes GPT partitions (EFI + OS), applies a Windows image from a mounted ISO, configures basic UEFI boot, services the offline image (removes features / provisioned apps), and optionally creates a Hyper-V VM using the VHDX.

## Prerequisites

- **Run as Administrator:** The script must be executed from an elevated PowerShell session.
- **PowerShell version:** Requires PowerShell 5.1 or newer due to use of built-in cmdlets and DISM commands.
- **Windows ISO downloaded and mounted:** Mount the Windows 11 ISO (right-click -> Mount, or use `Mount-DiskImage`) and note the assigned drive letter (e.g., `D:`). ISO images can be downloaded from the official Microsoft page: https://www.microsoft.com/software-download/windows11
- **DISM and bcdboot:** The script uses the built-in `dism` and `bcdboot` utilities. Ensure these commands are present on your path.
- **Hyper-V (optional):** If the Hyper-V module is available and you want a VM created automatically, ensure Hyper-V is enabled and that you can manually create a new VM.

> [!IMPORTANT]
> The script includes an "aggressive" list of features and provisioned app removals. Review the script before running if you need specific Windows features or provisioned packages preserved.

## Parameters

| Argument | Description | Required | Default |
|------------------------------|-----------------------------------------------------------------------------|:--------:|:-------:|
| **-IsoDrive** | Drive letter where the Windows ISO is mounted (string). Example: D:. | true | — |
| **-ImageIndex** | Index of the Windows image within `install.wim` or `install.esd` (int). Use DISM to list available indexes (for example `dism /Get-WimInfo /WimFile:D:\sources\install.wim`). | true | — |
| **-VhdPath** | Full path to create the VHDX file (string). Example: `C:\MinWin11.vhdx`. | true | — |
| **-VhdSizeGB** | Size of the VHDX in GB (int). | false | 25 |
| **-VmName** | Name of the Hyper-V VM to create (string). | false | MinWin11 |

## How to determine image index

Use DISM to list images in the WIM/ESD on the mounted ISO. Replace `D:` with your ISO drive letter:

```powershell
# For WIM
dism /Get-WimInfo /WimFile:D:\sources\install.wim

# For ESD (DISM supports reading ESD similarly)
dism /Get-ImageInfo /ImageFile:D:\sources\install.esd
```

Look for the `Index :` value you want to apply (for example, 1 for the first edition).

## Basic usage examples

Open an elevated PowerShell prompt and run (example values shown):

```powershell
# From the Tools folder
cd <path-to-repo>\Tools

# Basic: create a 25GB dynamic VHDX from the image at D:, using index 1
.\Build-MinWin11.ps1 -IsoDrive D: -ImageIndex 1 -VhdPath C:\MinWin11.vhdx

# With custom size and VM name
.\Build-MinWin11.ps1 -IsoDrive D: -ImageIndex 2 -VhdPath C:\MinWin11.vhdx -VhdSizeGB 40 -VmName "MyMinWin11"
```

## What the script does (high level)

- Locates `install.wim` or `install.esd` on the mounted ISO at `\sources`.
- Creates a dynamic VHDX at the path provided (`-VhdPath`) and mounts it.
- Initializes the disk as GPT and creates a 100MB EFI partition and the remaining OS partition.
- Formats the partitions (EFI = FAT32, OS = NTFS).
- Applies the Windows image to the OS partition using `dism /Apply-Image`.
- Creates UEFI boot files with `bcdboot`.
- Mounts an offline copy of the image for servicing and removes a predefined list of optional features and provisioned appx packages (see script for the removal list).
- Runs component-store cleanup (`/StartComponentCleanup /ResetBase`) to reduce size.
- Dismounts VHD and optionally creates a Hyper-V VM named `-VmName` if the Hyper-V cmdlets are present.

## Output

- A VHDX file at the path specified by `-VhdPath` (e.g., `C:\MinWin11.vhdx`).
- If Hyper-V is available and `-VmName` does not exist, a new Gen 2 VM is created and attached to the VHDX.

## Warnings & tips

- The script will throw an error if it cannot locate `install.wim` or `install.esd` in the ISO `sources` folder.
- Review and edit the features/provisioned-app removal lists in the script before running in production environments — the defaults are aggressive and intended for minimal builds.
- If you prefer to inspect the VHD before dismounting, modify the script or run the VHD mounting steps manually.
- Ensure sufficient free space on the volume where `-VhdPath` is located.

## Troubleshooting

- If the ISO is not mounted as a drive letter, use `Mount-DiskImage -ImagePath "C:\path\to\Win11.iso"` and then run `Get-Volume` or check Explorer to find the assigned drive letter.
- If `dism /Apply-Image` fails, verify the `-ImageIndex` value, and confirm whether the image file is `install.wim` or `install.esd`.
- If Hyper-V VM creation fails, verify the `Hyper-V` Windows feature is enabled and that you are running elevated PowerShell.

## Using with other VM Providers

- The produced VHDX (`C:\MinWin11.vhdx`) can be used with other hypervisors, but many providers require a different disk format; convert the VHDX to the format your provider expects before attaching.
- QEMU/KVM: convert to `qcow2` with `qemu-img convert -O qcow2`.
- VMware: convert to `vmdk` with `qemu-img convert -O vmdk` (or use VMware tools if available).
- VirtualBox: use `VBoxManage clonemedium disk --format VDI` or convert with `qemu-img` to `vdi`/`vmdk` as needed.
- Before converting, ensure the VHDX is dismounted and not in use. After conversion, attach the converted disk to a VM configured for UEFI/GPT (Gen2/EFI) and the appropriate disk controller.
- Expect to install or enable guest additions/tools for the target hypervisor and verify drivers (network, storage) inside the guest; hardware differences may require small post-boot fixes.
