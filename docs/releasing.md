# Publishing a release

[简体中文](releasing.zh-CN.md)

Pushing a tag matching `VERSION` starts `.github/workflows/release.yml`. It tests and builds x86_64 on `macos-15-intel` and arm64 on `macos-15`, using Xcode 26.3. Both builds must succeed before a GitHub Release is published. The apps use your self-signed certificate and are not notarized.

## Configure repository secrets

In **Settings → Secrets and variables → Actions → New repository secret**, add:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` containing the signing certificate **and its private key** |
| `P12_PASSWORD` | The password you choose when exporting that `.p12` |

The current local signing identity is `Flick Self-Signed Code Signing`. The workflow identifies the signer automatically from the imported `.p12`; no identity-name secret is required. Export only this signing identity, with its private key.

The current certificate's SHA-1 fingerprint is `F59A55AA31DD7E2DB36EF2ACD1FA467C2BE84547`. The local Makefile signs through Keychain and does not have a separate P12 password configured. You choose a new export password; it is not your macOS login password.

1. Open **Keychain Access → My Certificates**, find `Flick Self-Signed Code Signing`, and confirm that expanding it shows a private key.
2. Export the identity, including the private key, as `MacCask-signing.p12` into Downloads. Choose an export password and use it for `P12_PASSWORD`.
3. Copy its Base64 representation to the clipboard, then paste it into `BUILD_CERTIFICATE_BASE64`:

   ```sh
   base64 -i "$HOME/Downloads/MacCask-signing.p12" | pbcopy
   ```

Do not commit the `.p12` or its password. P12/PFX files and `.signing/` are ignored by Git. Missing secrets fail the workflow before the build jobs start; releases do not fall back to ad-hoc signing.

The runner creates its own random temporary keychain password, imports the identity, trusts the self-signed certificate on that disposable runner, and removes signing material afterward. No provisioning profile, Apple account, or manually created GitHub token is needed. The publish job uses GitHub's automatic token with `contents: write` permission.

## Publish a version

`VERSION` is the sole version source. Its initial content is `1.0.0`. Set a numeric `major.minor.patch` version before committing; the Makefile does not accept a `VERSION=...` override.

After committing the version and release changes, push the branch and matching tag:

```sh
git push origin HEAD
git tag "v$(cat VERSION)"
git push origin "v$(cat VERSION)"
```

Both `v1.0.0` and `1.0.0` are accepted for `VERSION=1.0.0`; mismatched tags fail validation. Any tag push invokes validation. Tags must point to a commit containing the workflow and matching version file.

The published release contains:

- `MacCask-1.0.0-macos-x86_64.zip` — Intel Macs.
- `MacCask-1.0.0-macos-arm64.zip` — Apple Silicon Macs.
- `SHA256SUMS` — checksums for both archives.

Each ZIP contains `MacCask.app`. The pipeline verifies the app's version, signature, and exact architecture before archiving. A new release remains a draft until all attachments have uploaded. Re-running a successful tag workflow can replace same-named attachments on the existing release.

## Build an archive locally

```sh
make release ARCH=x86_64
make release ARCH=arm64
```

Archives are written to `build/releases/`; the app bundle remains at `build/MacCask.app`. The last build replaces that bundle, so choose your Mac's architecture for the last build if you want to run it locally. CI uses separate native runners and runs tests on each architecture.

## Validation

Push `ci/release-validation` to test the full workflow without creating a Release. Once the workflow is on the default branch, you can also use **Actions → Build and release → Run workflow**. These runs build and sign both archives and upload them as Actions artifacts; only tag pushes publish a Release.

```sh
bash Tests/Release/test-version.sh
bash Tests/Release/test-signing-selection.sh
swift test
make release
```

Runner labels and installed Xcode versions are based on [GitHub's runner images](https://github.com/actions/runner-images). Certificate import follows [GitHub's macOS signing guidance](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), with additional trust setup for a self-signed certificate.
