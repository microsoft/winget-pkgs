Checklist for Pull Requests
- [ ] Have you signed the [Contributor License Agreement](https://cla.opensource.microsoft.com/microsoft/winget-pkgs)?
- [ ] Is there a linked Issue?

Manifests
- [ ] Have you checked that there aren't other open [pull requests](https://github.com/microsoft/winget-pkgs/pulls) for the same manifest update/change?
- [ ] This PR only modifies one (1) manifest
- [ ] Have you [validated](https://github.com/microsoft/winget-pkgs/blob/master/doc/Authoring.md#validation) your manifest locally with `winget validate --manifest <path>`?
- [ ] Have you tested your manifest locally with `winget install --manifest <path>`?
- [ ] Does your manifest conform to the [1.10 schema](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema/1.10.0)?

Note: `<path>` is the directory's name containing the manifest you're submitting.

---
