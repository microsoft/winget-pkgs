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

1. If I delete this entire template and go my own path, the core team may close my issue without further explanation or engagement.
1. If I list multiple apps in this one issue, the core team may close my issue without further explanation or engagement.
1. If I write an issue that has many duplicates, the core team may close my issue without further explanation or engagement (and without necessarily spending time to find the exact duplicate ID number).
1. If I leave the title incomplete when filing the issue, the core team may close my issue without further explanation or engagement.
1. If I file something completely blank in the body, the core team may close my issue without further explanation or engagement.

1. If this is an issue with the client, I will create the issue [there](https://github.com/microsoft/winget-cli/issues/new/choose)

All good? Then proceed!
-->

# Package Requested

- [ ] I would like someone else to build the manifest.
- [ ] I would like help so I can submit the manifest.
- [ ] I have performed a search and couldn't find this package.
- [ ] I think there is a new version available and I have provided the URL.

Manifest:


Fill out as much of the manifest metadata you can:


```YAML
PackageIdentifier:   # publisher.package format (example: "Microsoft.WindowsTerminal")
PackageVersion:      # version number format x.y.z.a (example: "1.6.10571.0")
PackageLocale:       # meta-data locale (example: "en-US")
Publisher:           # publisher name (example: "Microsoft Corporation")
PackageName:         # package name (example: "Windows Terminal")
License:             # package license (example: "MIT")
ShortDescription:    # package description (example: "The new Windows Terminal")
Installers: 
 - Architecture:     # installer architecture (example: "x64")
   InstallerType:    # installer type (example: "msix")
   InstallerUrl:     # installer URL (should be https://)
   InstallerSha256:  # SHA256 hash calculated from installer
ManifestType: singleton
ManifestVersion: 1.0.0
```
