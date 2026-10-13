# Publishing a release

[简体中文](releasing.zh-CN.md)

Pushing a tag matching `VERSION` starts `.github/workflows/release.yml`. Both architecture jobs use Apple Silicon `macos-26` runners with Xcode 26.6. SwiftPM cross-compiles the Intel executable with `--arch x86_64` and builds arm64 natively. The full test suite, including graphics rendering, runs in the native arm64 job; the Intel archive is independently compiled and its architecture and signature are verified. Both builds must succeed before a GitHub Release is published. The apps use your self-signed certificate and are not notarized.

## Configure repository secrets

In **Settings → Secrets and variables → Actions → New repository secret**, add:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` containing the signing certificate **and its private key** |
| `P12_PASSWORD` | The password you choose when exporting that `.p12` |
| `SPARKLE_PRIVATE_KEY` | Exported Sparkle Ed25519 private key; paste the file contents without Base64-encoding again |

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

- `MacCask-1.0.0-macos-x86_64.dmg` — Intel Macs.
- `MacCask-1.0.0-macos-arm64.dmg` — Apple Silicon Macs.
- `SHA256SUMS` — checksums for both disk images.

Each DMG contains `MacCask.app` and an `Applications` shortcut. Open the DMG and drag the app to Applications. The pipeline verifies the app's version, signature, and exact architecture before archiving. A new release remains a draft until all attachments have uploaded. Re-running a successful tag workflow can replace same-named attachments on the existing release.

## Build a DMG locally

```sh
make release ARCH=x86_64
make release ARCH=arm64
```

DMG files are written to `build/releases/`; the app bundle remains at `build/MacCask.app`. The last build replaces that bundle, so choose your Mac's architecture for the last build if you want to run it locally. CI uses separate Apple Silicon runners for the two target architectures, with the full tests in the native arm64 job. Intel GitHub virtual machines cannot reliably run the graphics tests.

## Validation

Push `ci/release-validation` to test the full workflow without creating a Release. Once the workflow is on the default branch, you can also use **Actions → Build and release → Run workflow**. These runs build and sign both disk images and upload them as Actions artifacts; only tag pushes publish a Release.

```sh
bash Tests/Release/test-version.sh
bash Tests/Release/test-signing-selection.sh
swift test
make release
```

Runner labels and installed Xcode versions are based on [GitHub's runner images](https://github.com/actions/runner-images). Certificate import follows [GitHub's macOS signing guidance](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), with additional trust setup for a self-signed certificate.

## In-app updates

Actions generates and signs `appcast-arm64.xml` and `appcast-x86_64.xml`, then uploads them alongside the DMGs. Each app reads its architecture-specific feed through GitHub's `releases/latest/download/` endpoint. No GitHub Pages setup or separate server is needed. Do not mark an older release without feeds as Latest.

Copy the generated update key from the repository root and paste it into `SPARKLE_PRIVATE_KEY`:

```sh
pbcopy < .signing/sparkle-private-key
```

The key is also stored in the login Keychain under account `com.maccask.app.sparkle`. The public key in `Resources/SparklePublicKey.txt` is embedded during packaging. Back up the private key and retain it across releases. Do not generate a new key for each version. Keep the two existing P12 secrets unchanged.

The updater verifies signed feeds and DMGs before extraction. Automatic checks are off by default and can be enabled in Settings. Sparkle presents download, installation, and restart controls. Install the app in a writable location before updating; an app running from a read-only DMG cannot replace itself. Existing versions without the updater require one manual installation.

Release builds use `VERSION` for both `CFBundleVersion` and `CFBundleShortVersionString`. Increase it for each update; CI run numbers and local timestamps are no longer used. The first manual installation migrates older builds to this version scheme. Reserve `BUILD` overrides for development validation.

Local feed validation:

```sh
make release
SPARKLE_PRIVATE_KEY="$(cat .signing/sparkle-private-key)" bash Scripts/Release/generate-appcast.sh build/releases "$(uname -m)" "v$(cat VERSION)"
python3 Tests/Release/test-updater.py
```

Self-signing is not Apple notarization. Before release, validate download, quit, replacement, and relaunch using two distinct app versions in a test location. Do not publish artificial production versions for testing.

Background update checks show an in-app notice without opening a window or downloading the update. Choose **View Update…** when ready to review and install it.

### Local end-to-end update test

With Sparkle resolved, `.signing/sparkle-private-key` available, and the local signing identity installed:

```sh
python3 Tests/Release/run-update-integration.py
python3 Tests/Release/run-update-integration.py --scenario cancel
```

These tests briefly open an isolated test app's Sparkle window and drive controls within that process. They reuse the production updater and notice view, serve signed fixtures over loopback, and use a unique bundle identifier. The install scenario verifies download, replacement, and actual relaunch; cancel verifies no download or replacement. Nothing in Applications is replaced. Evidence remains in the printed build/update-integration-* directory. A macOS GUI session is required; these tests are not run in headless CI.
