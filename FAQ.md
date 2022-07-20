# Frequently Asked Questions
## Table of Contents
1. [What is an ARP Entry?](What-is-an-ARP-Entry?)
1. [What should I do if a package is being published by a new publisher?](#What-should-I-do-if-a-package-is-being-published-by-a-new-publisher?)
-----
## **What is an ARP Entry?**
ARP stands for `A`dd and `R`emove `P`rograms. In Windows, installer files put information about the package they have installed into the Windows Registry. This information is used to tell Windows exactly what a program is and how to uninstall or modify it. Users can view these entries through the Add and Remove Programs option in Control Panel, or by running `appwiz.cpl`. Each entry in the table is an ARP Entry, and the Windows Package Manager uses these entries to help determine which applications are currently installed on your system.

## **What should I do if a package is being published by a new publisher?**
The best practice for this is to create a situation where the package automatically switches to the new publisher using the ARP Entries for the package. To do this, two copies of the package must be added to the repository - one under the original package identifier and one under a new package identifier for the new publisher. This will cause anyone on a package published by the old publisher to be updated to the new version, at which point the ARP Entries will cause the Windows Package Manager to match the package to the new publisher and all future updates will be taken from the new package identifier.

For the package version added under the old publisher, the metadata should be updated to be accurate to the new publisher, with the exception of the `Publisher` field, which should remain as the old publisher. Additionally, the `AppsAndFeaturesEntries` should be added for each installer node, being sure to keep the `Publisher` entry as the old publisher. The `ProductCode` entries should not be specified under this version.

For the package version added under the new package identifier, the metadata should be complete and accurate. Additionally, the `AppsAndFeaturesEntries` should be added for each installer node. The `ProductCode` entries should be specified under this version.

*Additional Notes*:
While this is currently the best practice, this may change in the future with the implementation of [microsoft/winget-cl#1899](https://github.com/microsoft/winget-cli/issues/1899) and [microsoft/winget-cl#1900](https://github.com/microsoft/winget-cli/issues/1900).