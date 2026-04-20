# jenkins-deploy-skill (English)

![Version](https://img.shields.io/github/v/tag/maimingliang/jenkins-deploy-skill?label=version&style=flat-square)
![License](https://img.shields.io/github/license/maimingliang/jenkins-deploy-skill?style=flat-square)
![Repo Size](https://img.shields.io/github/repo-size/maimingliang/jenkins-deploy-skill?style=flat-square)

---

> [!CAUTION]
> **Disclaimer**: This tool is designed for development and testing environments only. Automated merging and triggering of Jenkins builds involve high-risk operations. **DO NOT use this tool for production deployments.** The author is not responsible for any production issues or data loss caused by the use of this tool.

## Technical Overview

An AI Agent skill/prompt that automates the "merge -> push -> trigger Jenkins build" workflow. It merges your feature branch into a deploy branch via Git and triggers a parameterised Jenkins build through the REST API.

### Prerequisites

Before getting started, verify your environment is ready:

```powershell

# Check Git is installed and configured
git config --global user.name
git config --global user.email

```

```bash
# Recommended on macOS / Linux
python3 --version
```

Here `python3` simply means a Python 3 interpreter. If `python` in your environment already points to Python 3, you can use `python` directly.

### Secure Credential Setup

Before running the script, prepare your Jenkins API Token in a secure way:

**For Windows**
- Open **Credential Manager** -> **Windows Credentials** -> **Add a generic credential**
- **Target**: the `credentialTarget` from `config.json`, for example `jenkins-api-auth-id`
- **Username**: your Jenkins username
- **Password**: your Jenkins API Token

**For macOS**
- Save the credential to Keychain:
  ```bash
  security add-generic-password -s "jenkins-api-auth-id" -a "your-jenkins-username" -w "your-api-token"
  ```
- The `-s` value must match `credentialTarget` in `config.json`

**For Linux / CI / fallback**
- Export environment variables before running:
  ```bash
  export JENKINS_USERNAME="your-jenkins-username"
  export JENKINS_API_TOKEN="your-api-token"
  ```

### Installation (For AI Assistants)

#### 1. Automatic Installation (Recommended)

If your AI assistant (e.g., Codex, Claude Code) supports installing skills directly from a repository URL, simply send the following command:

> [!TIP]
> Copy the full line below (including the trailing `skill` keyword) and send it directly:

```text
https://github.com/maimingliang/jenkins-deploy-skill skill
```

<details>
<summary>Manual Installation</summary>

1. Download or `git clone` this repository to a permanent location on your machine.
2. Connect `SKILL.md` to the assistant you use in the project where you actually write code:
   - **Codex**: place this entire folder into your global skills directory
     - Windows: `%USERPROFILE%\.codex\skills\`
     - macOS/Linux: `~/.codex/skills/`
   - **Cursor / Windsurf**: copy the contents of `SKILL.md` to `.cursorrules`
     - Windows: `%USERPROFILE%\.cursorrules`
     - macOS/Linux: `~/.cursorrules`
   - **Claude Code (CLI)**: place this entire folder into the Claude skills directory
     - Windows: `%USERPROFILE%\.claude\skills\`
     - macOS/Linux: `~/.claude/skills/`
   - **GitHub Copilot**: copy the contents to `.github/copilot-instructions.md`
     - Windows: `%USERPROFILE%\.github\copilot-instructions.md`
     - macOS/Linux: `~/.github/copilot-instructions.md`
   - **Claude Projects / ChatGPT**: upload `SKILL.md` into the knowledge base or custom instructions

Not sure which install path to use? Start with **Install By Chat** above. If you prefer a manual setup, use the options below:

- If you are not sure which one to choose, start with **Codex** or **Claude Code**. They can use the bundled `scripts/` directly and usually require the least extra setup.
- **Filesystem-based installs** such as Codex or Claude skills directories are recommended if you want to run the bundled `scripts/` directly.
- **Text-only installs** such as `.cursorrules`, Copilot instructions, or knowledge-base uploads still preserve the workflow guidance, but they do not automatically include the local `scripts/` folder. If you want script-based triggering in that setup, copy the scripts into a local tools directory first. Otherwise, use the Jenkins Web UI path from `SKILL.md`.

</details>

### Quick Start

If you are setting up a single Jenkins job, start here. Run all commands in the root of the `jenkins-deploy-skill` directory.

This section introduces the most common single-project lightweight configuration (refer to `config.example.json`). We recommend explicitly defining your `dev`, `test`, and `pre` environments within the `environments` block for clear management and switching. If you need to manage multiple independent projects through a single Skill, please refer to [Advanced: Multi-Project And Multi-Environment](#advanced-multi-project-and-multi-environment) below.

#### Option 1: Configure Manually

1. Generate `config.json` from the template.

   **Windows (PowerShell):**
   ```powershell
   Copy-Item config.example.json config.json
   ```

   **macOS / Linux (Bash):**
   ```bash
   cp config.example.json config.json
   ```

2. Open `config.json` in the root of the `jenkins-deploy-skill` directory with your preferred editor, such as VS Code or Notepad.

3. Replace the placeholder values with your real Jenkins configuration. The template itself stays as plain JSON so it works cleanly with editors, validators, and automation tools.

4. The key fields are:

   | Field | Description | Typical value |
   |-------|-------------|---------------|
   | `defaultEnvironment` | Default environment when no environment is specified | `dev` |
   | `branchParamName` | Jenkins parameter name used for the branch | `BRANCH` |
   | `environments` | Environment blocks such as `dev`, `test`, and `pre`, each with its own Jenkins URL, job name, branch, and `credentialTarget` | see `config.example.json` |
   | `gitFlow` | Optional deployment workflow rules:<br>• `autoCommitBeforeDeploy`: Auto-commit local changes before deployment<br>• `allowCascadePromote`: Enable one-click sync from working branch to test/pre (automates integration and sync) | `{"autoCommitBeforeDeploy": true, "allowCascadePromote": true}` |


<details>
<summary>Option 2: Write config.json From The Command Line</summary>

1. If you prefer staying in the terminal, write the file directly instead of opening an editor.

   **Windows (PowerShell):**
   ```powershell
   @'
   {
     "gitFlow": {
       "autoCommitBeforeDeploy": true,
       "allowCascadePromote": true
     },
     "defaultEnvironment": "dev",
     "branchParamName": "BRANCH",
     "environments": {
       "dev": {
         "jenkinsBaseUrl": "http://your-jenkins-server:8080",
         "jobName": "your-job-name",
         "credentialTarget": "jenkins-api-auth-id",
         "branch": "dev"
       },
       "test": {
         "jenkinsBaseUrl": "https://your-test-jenkins-server:8080",
         "jobName": "your-test-job-name",
         "credentialTarget": "jenkins-test-auth-id",
         "branch": "test"
       }
     }
   }
   '@ | Set-Content .\config.json -Encoding UTF8
   ```

   **macOS / Linux (Bash):**
   ```bash
   cat > ./config.json <<'EOF'
   {
     "gitFlow": {
       "autoCommitBeforeDeploy": true,
       "allowCascadePromote": true
     },
     "defaultEnvironment": "dev",
     "branchParamName": "BRANCH",
     "environments": {
       "dev": {
         "jenkinsBaseUrl": "http://your-jenkins-server:8080",
         "jobName": "your-job-name",
         "credentialTarget": "jenkins-api-auth-id",
         "branch": "dev"
       },
       "test": {
         "jenkinsBaseUrl": "https://your-test-jenkins-server:8080",
         "jobName": "your-test-job-name",
         "credentialTarget": "jenkins-test-auth-id",
         "branch": "test"
       }
     }
   }
   EOF
   ```

2. Verify that `config.json` exists and contains the expected values.

   **Windows (PowerShell):**
   ```powershell
   Get-Content .\config.json
   ```

   **macOS / Linux (Bash):**
   ```bash
   cat ./config.json
   ```

</details>

#### Usage Example

Once the setup is complete, the best way to verify it is to issue a deployment command directly in the chat:

```text
deploy to dev
```

If you use multiple environments, you can also say:

```text
deploy to test
```

On a successful run, the skill should do three things in order:

1. Integrate or promote the correct Git branch for the target environment
2. Push the target deploy branch to the remote repository
3. Trigger the Jenkins job for that environment

You should then see a new queued or running build for the configured job in Jenkins. This is the most direct way to verify the success of the happy path.


### Recommended Git Workflow

This skill works best when each environment has a clear role.

> Note: `dev`, `test`, `pre`, and `gray` are common examples, not fixed standards. Different teams may use different environment names. The actual behavior of this skill is driven by the environment configuration in `config.json`, especially each environment's `branch`, Jenkins URL, job, and credentials.

#### Environment Roles

| Environment | Role | Receives merges from |
|-------------|------|----------------------|
| `dev` | **Dev (Internal)** | your working branch (e.g., `feature/login`) |
| `test` | **Test (QA)** | the branch configured for `dev` |
| `pre` | **Pre-release (Staging)** | the branch configured for `test` |
| `gray` | **Gray (Alpha)** | manual only by default |

#### Sync Flow

```text
feature/login ──► dev ──► test ──► pre ──► (gray: manual)
     ▲               │         │
     │               │         │
  auto-commit      sync      sync
  (if needed)   (ff-only)  (ff-only)
```

- **Deploy to `dev`**: **Integrate** (Merge) your feature branch into the Dev environment.
- **Deploy to `test`**: **Sync** (Promote) the Dev stage code to the Test environment for verification.
- **Deploy to `pre`**: **Sync** (Promote) the verified Test code to the Pre-release environment.

> ⚠️ By default, `test` and `pre` are **Sync (Promotion)** stages. They do not receive a working branch directly.

#### Branch Mapping

The target Git branch is determined by your `config.json` structure:

- **Single-project**: Define the `branch` for each environment under the `environments` block.
- **Multi-project**: Map branches via the `projects.<name>.environments.<env>.branch` path.

The system automatically selects the correct target branch based on the requested environment.

#### Uncommitted Changes

If your working branch still has uncommitted changes, the skill can create one controlled auto-commit on that working branch before deployment. It will not commit directly on `dev`, `test`, `pre`, or any long-lived environment branch.

Internally, the skill uses a temporary local branch to protect your long-lived branches and avoid rewriting your own branch history.

#### `gitFlow` Configuration

| Key | Default | Effect |
|-----|---------|--------|
| `autoCommitBeforeDeploy` | `true` | Allows one controlled auto-commit on your working branch before deploy |
| `allowCascadePromote` | `true` | Allows chained sync. For example, saying "deploy to test" from `feature/login` can first integrate into `dev`, then sync `dev` to `test` |



### Advanced: Multi-Project And Multi-Environment

When a single Skill needs to maintain multiple independent projects, we recommend using the multi-project configuration scheme.

#### Configuration Steps

1. **Initialize Template**: Save `config.multi-project.example.json` as `config.json`.

   **Windows (PowerShell):**
   ```powershell
   Copy-Item config.multi-project.example.json config.json
   ```
   
   **macOS / Linux (Bash):**
   ```bash
   cp config.multi-project.example.json config.json
   ```

2. **Define Projects & Environments**: Declare each project and its specific `environments` within the `projects` object. Each project/environment can use its own Jenkins URL, job name, branch, and `credentialTarget`.
3. **Set Defaults**: Use `defaultProject` to specify a fallback and define shared Jenkins URLs or credential IDs in `projects.<name>.defaults`.

#### Usage Examples

Once configured, the AI assistant will automatically recognize different projects. You can say:

```text
deploy demo-admin to test
```

Or for a single-project setup:

```text
deploy to test
```

The skill will decide the target project, environment, branch, Jenkins URL, and credentials from `config.json`.

<details>
<summary>If You Run The Scripts Manually</summary>

The options below are only for users who run `trigger_jenkins_build.ps1` or `trigger_jenkins_build.py` directly.

##### Project Selection

| Case | Result |
|------|--------|
| You pass `--project` or `-Project` | That project is used |
| You do not pass a project | The script uses `defaultProject` |
| There is only one project in the file | The script can infer it |
| There are multiple projects and no `defaultProject` | Specify the project explicitly |

##### Config File Selection

| Case | Result |
|------|--------|
| You pass `--config-file` or `-ConfigFile` | That file is used |
| You do not pass a config file | The script reads `config.json` only |
| `config.multi-project.json` exists next to `config.json` | It is not picked automatically |
| You want to use `config.multi-project.example.json` | Copy or rename it to `config.json`, or pass it explicitly with `--config-file` |

##### Environment Selection

| Case | Result |
|------|--------|
| You pass `--target-env` or `-TargetEnv` | That environment is used |
| You do not pass an environment and `defaultEnvironment` exists | `defaultEnvironment` is used |
| No `defaultEnvironment`, but `dev` exists | `dev` is used by default |

##### Manual Script Examples

**Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py --target-env test
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -Project demo-admin -TargetEnv test
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py --project demo-admin --target-env test
```

</details>

### Troubleshooting

#### Merge Conflicts

A Git merge conflict will interrupt the flow. If a conflict occurs:

1. Run `git merge --abort` or `git rebase --abort`.
2. Resolve the conflict manually in your IDE.
3. Commit the resolved changes locally.
4. Invoke the skill again to continue the push and Jenkins trigger flow.

#### Push Succeeded But Jenkins Trigger Failed

- Your code may already be on the target branch even if Jenkins did not start successfully.
- In that case, do not roll back Git by default.
- First fix the Jenkins-side problem, such as credentials, crumb access, or network reachability.
- Then rerun the skill or trigger the same Jenkins job manually.

#### Jenkins Authentication Failed

- Confirm that `credentialTarget` matches the credential saved in Windows Credential Manager or macOS Keychain.
- Make sure the Jenkins username and API token are still valid.
- If you are using environment variables, confirm `JENKINS_USERNAME` and `JENKINS_API_TOKEN` are exported in the same shell session.

#### CSRF Crumb Errors

- Make sure the Jenkins base URL is correct and reachable from your machine.
- Confirm that the Jenkins user behind the API token has permission to access the crumb issuer endpoint.
- If your Jenkins is behind a reverse proxy, verify that the proxy is not stripping required headers.

#### `config.json` Not Found Or Wrong File Used

- By default, the scripts read `config.json` only.
- If you want a different file, pass `--config-file` or `-ConfigFile` explicitly.
- `config.multi-project.example.json` is only a template until you copy or point to it directly.

#### Push Was Rejected By Branch Protection

- This skill assumes the target deploy branch allows direct push.
- If your repository protects `dev`, `test`, or `pre`, the push may fail even when the local merge succeeded.
- In that case, switch to your team's pull request flow or relax branch protection for the deployment branch.

#### `--ff-only` Sync Failed

- This usually means the upstream branch moved forward and the sync is no longer a fast-forward.
- Sync the upstream branch first, then rerun the skill.
- A common recovery flow for `dev -> test` sync is:

```bash
git fetch origin
git checkout dev
git pull --ff-only
```

- If the failure happened while integrating your working branch into `dev`, first sync your working branch with the latest `origin/dev` according to your team policy, resolve any conflicts, and then rerun the skill.

### License

[MIT](./LICENSE)

## Project Metadata

| Field | Value |
|-------|-------|
| Version | `1.2.2` |
| Author | `maiml` |
| Repository | [maimingliang/jenkins-deploy-skill](https://github.com/maimingliang/jenkins-deploy-skill) |
| Tags | `jenkins`, `deploy`, `ci-cd`, `git`, `devops` |
