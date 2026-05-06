<!-- PR Title Format: "New package: Publisher.Name version X.Y.Z" or "Update: Publisher.Name to X.Y.Z" -->

## 📖 Description
<!-- Describe what this PR changes. For manifest submissions, include the package name and version. -->

## ✅ Checklist
<!-- Place an "x" between the brackets to check an item. e.g: [x] -->

- [ ] Signed the [Contributor License Agreement](https://cla.opensource.microsoft.com)
- [ ] Linked to an issue (if applicable)
  <!-- Example: Resolves #328283 -->
  - Resolves #[Issue Number]

## 📦 Manifest Checklist

- [ ] Checked that there aren't other open [pull requests](https://github.com/microsoft/winget-pkgs/pulls) for the same manifest update/change
- [ ] This PR only modifies one (1) manifest
- [ ] Validated manifest locally with `winget validate --manifest <path>` ([validation guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/ValidationFailureGuide.md))
- [ ] Tested manifest locally with `winget install --manifest <path>`
- [ ] Manifest conforms to the [1.12 schema](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema/1.12.0)

> **Note:** `<path>` is the directory containing the manifest you're submitting.