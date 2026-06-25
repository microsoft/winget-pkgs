Updated to **3.1.6.0** with the MSI now published on R2 and served by our download endpoint.

**Manifest**
- **InstallerUrl**: https://legacyfileconverter.com/api/download
- **InstallerSha256**: `07CD2DB58586DA823CB55DB47062C32BCBE3F070C637EBA6BDADDB2E997139E6`
- **ProductCode**: `{3CA354CC-DD05-4CE1-BCAC-C3B3B021673B}`
- **ReleaseDate**: 2026-06-25

**Publisher-side sync (deployed with this update)**
- `/api/download` now redirects to `LegacyFileConverter-3.1.6.msi` on R2
- Hash verified against the R2 object directly and via `VstsAgent/3.0` + `WinGet/1.0` user agents (237,408,256 bytes)

**Note:** If Vercel has `NEXT_PUBLIC_DOWNLOAD_REDIRECT_URL` set explicitly, it must point to the 3.1.6 MSI (or be removed so the site default applies). Otherwise validation may still fetch an older file.

Please re-run validation when ready.
