Updated the manifest to **3.1.5.0** with the current release MSI served by our download endpoint.

**Changes:**
- Bumped manifest version folder from `3.1.4.0` → `3.1.5.0`
- **InstallerUrl** (unchanged): https://legacyfileconverter.com/api/download
- **InstallerSha256**: `40E270A2DD434195CD8695D40B97109F48824B60F83728966871F871DD4C2DCD`
- **ProductCode**: `{8168C1D3-E357-4DD4-86B7-9757285B2B0E}`
- **ReleaseDate**: 2026-06-15

**What changed in 3.1.5.0 vs 3.1.4.0:**
- Archive conversion fixes (temp path cleanup and parallel error reporting)
- Same signed MSI build: in-app Stripe checkout (WebView2) + Explorer shell extension (preview/thumbnails)

**Verification on our side:**
- `winget validate --manifest .../3.1.5.0` — passed
- Downloaded via `https://legacyfileconverter.com/api/download` with `WinGet/1.0` and `VstsAgent/3.0` user agents — both redirect to `LegacyFileConverter-3.1.5.msi` and hash to the SHA256 above (231,702,528 bytes)

Please re-run validation when ready. Thanks!
