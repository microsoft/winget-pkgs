---
name: "Package Request/Submission 👀"
about: Suggest a package for submission (this does not mean you have to implement it)
title: ''
labels: Help-Wanted
assignees: ''

---

<!-- 
🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨

I ACKNOWLEDGE THE FOLLOWING BEFORE PROCEEDING:
1. It might be easier to add the manifest myself.
2. It is probably faster if I add the manifest myself.

2. If I delete this entire template and go my own path, the core team may close my issue without further explanation or engagement.
3. If I list multiple apps in this one issue, the core team may close my issue without further explanation or engagement.
4. If I write an issue that has many duplicates, the core team may close my issue without further explanation or engagement (and without necessarily spending time to find the exact duplicate ID number).
5. If I leave the title incomplete when filing the issue, the core team may close my issue without further explanation or engagement.
6. If I file something completely blank in the body, the core team may close my issue without further explanation or engagement.

7. If this is an issue with the client, I will create the issue [there](https://github.com/microsoft/winget-cli/issues/new/choose)
All good? Then proceed!
-->

# Package Requested

Manifest:


Fill out as much of the manifest as you can:


```YAML
Id: string # publisher.package format
Publisher: string # the name of the publisher
Name: string # the name of the application
Version: string # version numbering format
License: string # the open source license or copyright
InstallerType: string # enumeration of supported installer types (exe, msi, msix, inno, wix, nullsoft, appx)
Installers:
  - Arch: string # enumeration of supported architectures
    Url: string # path to download installation file
    Sha256: string # SHA256 calculated from installer
# ManifestVersion: 0.1.0
```
