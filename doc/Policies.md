# Community Repository Policies

## Moderation
Manifests submitted to the community repository are subject to [moderation](Moderation.md).

## Installer Behaviors
The packages submitted to the community repository must be able to install without requiring user interaction. The default mechanism used in WinGet is "silent with progress". This means installers may launch a UI experience, but users must not be required to interact with this UI to complete a successful installation.

## Manifest Agreements
WinGet manifests support adding agreements to manifests. These agreements are between the publisher and the user (or organization) installing the software. These applications are licensed to you by their owner. Microsoft is not responsible for, nor does it grant any licenses to, third-party packages.

When switches passed to installers represent an explicit agreement between the publisher and the user, agreements must be added to the manifest. The community repository will allow the agreement title and the agreement URL, but not the agreement body to be included. Only verified developers are allowed to provide the agreement text.

## Manifest URLs
The URLs in manifests should come from official sources/publishers for packages. In particular any URLs for installers need to be discoverable on the publishers website. In many cases the URLs for installers come from a CDN, and HTTP redirects are used to find the "final" url for installers. Some software is delivered via a "vanity" URL and publishers replace the binaries which will cause a hash mismatch until a new version of the manifest is published. The preference for WinGet manifests is to use unique URLs per version of a package to avoid the hash-mismatch errors.

