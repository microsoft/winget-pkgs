Checklist for Pull Requests
- [ ] Have you signed the [Contributor License Agreement](https://cla.opensource.microsoft.com/microsoft/winget-pkgs)?
- [ ] Is there a linked Issue?  If so, fill in the Issue number below. Routine manifest submissions do not require a linked issue.
   <!-- Example: Resolves #328283 -->
  - Resolves #[Issue Number]

Manifests
- [ ] Have you checked that there aren't other open [pull requests](https://github.com/microsoft/winget-pkgs/pulls) for the same manifest update/change?
- [ ] This PR only modifies one (1) package version (one multi-file manifest set)
- [ ] This PR does not include non-manifest file changes such as `README.md`, `doc/`, spelling files, or tooling updates
- [ ] Have you [validated](https://github.com/microsoft/winget-pkgs/blob/master/doc/Authoring.md#validation) your manifest locally with `winget validate --manifest <path>`?
- [ ] Have you tested your manifest locally with `winget install --manifest <path>`?
- [ ] Does your manifest conform to the [1.12 schema](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema/1.12.0)?
- [ ] Have you reviewed the [first-time contributor checklist](https://github.com/microsoft/winget-pkgs/blob/master/doc/FirstContribution.md)?

Note: `<path>` is the directory's name containing the manifest you're submitting.

---
