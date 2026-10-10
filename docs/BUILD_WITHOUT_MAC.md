# Build the IPA from Windows using GitHub Actions

You do not need to own a Mac. This project includes `.github/workflows/build-ipa.yml`, which builds on **GitHub’s cloud Mac** and provides a downloadable unsigned IPA. Sign/install it with Sideloadly on Windows. The build workflow does not require your Apple ID or signing certificates.

The workflow runs automatically when source is pushed to `main`, and can also be started manually. The selected repository is `blankayn/IOS4OS24`. A compiled IPA is available only after its workflow completes successfully; see that repository’s Actions tab for the current status.

**First build completed successfully:** [download the IPA artifact](https://github.com/blankayn/IOS4OS24/actions/runs/38024634655/artifacts/11659562828). Extract the ZIP and use `iOS26Legacy-unsigned.ipa` with Sideloadly. A verified local copy is also saved in this workspace’s `artifacts` folder. The downloaded app contains an arm64 executable with an iOS 12.0 minimum; device installation and performance have not yet been tested.

## Steps in your Windows browser

1. Download and extract `artifacts/iOS26Legacy-source.zip` using File Explorer. Open the extracted `iOS26Legacy-source` folder.
2. Sign in to [GitHub](https://github.com/) and [create a repository](https://github.com/new). Use a private repository if you want to keep your source private. GitHub Actions usage is subject to your account’s included minutes and spending settings; a paid Apple developer account is not required for this unsigned build.
3. Upload the **contents** of the extracted folder into the repository root, then commit. The root should contain `iOS26Legacy.xcodeproj`, `iOS26Legacy`, `scripts`, `tools`, and `.github/workflows/build-ipa.yml`, along with the other supplied files. Do not upload only the ZIP or nest everything under another directory. On a new/empty repository, choose **uploading an existing file**; on an existing one, use **Add file → Upload files**. Make sure the `.github` folder is included. If your browser omits it, use **Add file → Create new file**, name the file `.github/workflows/build-ipa.yml`, and paste the supplied workflow’s exact text.
4. Open the repository’s **Actions** tab, select **Build iOS 12 IPA**, then **Run workflow**. Enable Actions if GitHub asks. The workflow must be on the default branch to appear in this menu. [GitHub’s manual workflow instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
5. Wait for a successful green build. Open that run and scroll to **Artifacts**. Download **iOS26Legacy-IPA**, extract the artifact ZIP, and locate **`iOS26Legacy-unsigned.ipa`**. GitHub artifact downloads require signing in. Build output is retained for seven days; you can run the workflow again to recreate it. [Downloading workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)
6. Drag that `.ipa` into **Sideloadly on Windows**, connect your iPhone, choose it, enter your Apple ID in Sideloadly and click **Start**. Trust the developer identity in the iPhone’s Settings if prompted. See the main README for the installation and seven-day re-signing details.

If compilation fails, download **iOS26Legacy-build-log** or open the failed step’s log and share the compiler errors here. The IPA artifact is uploaded only after compilation and packaging succeed. A successful cloud build verifies compilation; actual iPhone 6 performance still needs device testing.

## Legacy runner availability

As checked on **October 10, 2026**, GitHub’s macOS 14 image lists **Xcode 15.4** at `/Applications/Xcode_15.4.app`. That runner is scheduled to retire on **November 2, 2026** and may have deprecation outages before then. [GitHub’s macOS 14 image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md), [runner retirement announcement](https://github.com/actions/runner-images/issues/13518).

The workflow deliberately selects that image and toolchain. After retirement, use a cloud Mac service or a self-hosted Mac runner that supports Xcode 15; changing to `macos-latest` alone does not preserve the supported iOS 12 toolchain. Keep the deployment target at `12.0` and retain the script’s minimum-OS check. No newer toolchain workaround or iOS 12 compatibility has been tested here.
