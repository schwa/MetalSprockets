# Buildkite

GitHub Actions runners use a paravirtual GPU. Buildkite runs the full suite on a self-hosted Apple silicon Mac, so GPU
tests run on real hardware. The pipeline is `.buildkite/pipeline.yml`:

| Step | What it runs | Blocking |
| --- | --- | --- |
| Lint | `swiftlint --strict` | Yes |
| Test | `swift build` and `swift test` with `-warnings-as-errors` (API Validation off on `main`) | Yes |
| Example | The example app for macOS, iOS and visionOS | Yes |
| Public API snapshot | `swift-api-tool` diff against `.public-api.yaml` | No (see #391) |

Only one test step runs at a time on an agent, so builds do not compete for the GPU.

## Agent Mac requirements

- An Apple silicon Mac on macOS 26 or later.
- Xcode 26.4 or later (the version GitHub Actions uses), selected with `xcode-select`.
- The Metal toolchain: `xcodebuild -downloadComponent MetalToolchain`.
- Package plugins trusted: `defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidation -bool YES`.
- `swiftlint` (`brew install swiftlint`).
- `swift-api-tool` 0.2.0 from crates.io (`cargo install swift-api-tool --version 0.2.0`), the same build as GitHub Actions.
- A logged-in user session. Metal needs a GPU session; an agent started only as a system daemon may not get one.

## Install the agent

1. In Buildkite, open **Agents** and copy the agent token.
2. Install and configure the agent:

   ```sh
   brew install buildkite/buildkite/buildkite-agent
   ```

   In `$(brew --prefix)/etc/buildkite-agent/buildkite-agent.cfg`, set:

   ```ini
   token="<agent token>"
   name="%hostname-%spawn"
   ```

   Each agent process needs a unique name: agents with the same name share one build directory, and parallel jobs
   then delete each other's files. Run only the `brew services` agent; stop any agent started by hand.

   The pipeline runs on the cluster queue `default-queue`. Every agent on that queue must be an Apple silicon Mac with Xcode.

3. Start the agent as a user service, so it runs in the logged-in session:

   ```sh
   brew services start buildkite/buildkite/buildkite-agent
   ```

4. Make sure the agent appears in **Agents** as connected, on `default-queue`.

## Create the pipeline

1. In Buildkite, create a pipeline for `https://github.com/schwa/MetalSprockets`.
2. Set its steps to upload the repository file:

   ```yaml
   steps:
     - label: ":pipeline: Upload"
       command: "buildkite-agent pipeline upload"
       agents:
         queue: "default-queue"
   ```

3. Connect the GitHub webhook that Buildkite offers, so pushes start builds.
4. Use the HTTPS repository URL (`https://github.com/schwa/MetalSprockets.git`). The repository is public, so the
   agent needs no GitHub credentials. The SSH URL fails unless the agent Mac has an SSH key that GitHub accepts.
