---
name: jenkins-deploy-skill
description: >
  Use this skill whenever the user mentions deploying, pushing to Jenkins,
  triggering a build, or merging to a deploy branch such as dev, test, or pre.
  It automates "merge -> push -> Jenkins build" with secure credential handling
  across Windows, macOS, and Linux. Invoke it for requests like "帮我部署",
  "push 到 test 环境", "deploy pre", or "触发 Jenkins 构建".
---

# Jenkins Deploy Skill

## Goal

- Merge your changes into the **deploy branch** (Default: `dev`)
- Trigger a Jenkins Job build on that branch
- Branch, URL, and credentials can dynamically change based on the target environment

## Prerequisites

Before using this skill you need to:

1. Set up your `config.json` — copy `config.example.json` and fill in your values
2. Store your Jenkins API Token in Windows Credential Manager (see [Jenkins Token Setup](#jenkins-token-setup))

## Pre-deploy Checks

Run in your project root:

```powershell
git status -sb
git config --global user.name
git config --global user.email
git remote -v
```

Requirements:

- Working tree should be clean
- `user.email` must be a normal email — must NOT contain passwords or tokens
- `remote origin` must NOT contain `user:password@`

## Handling Updates on the Deploy Branch

Before deploying, make sure your local branch is based on the latest remote state.

```powershell
git fetch origin
```

If publishing from a feature branch:

```powershell
git checkout <your-branch>
git rebase origin/<deploy-branch>
```

If working directly on the deploy branch:

```powershell
git checkout <deploy-branch>
git pull --ff-only
git merge --ff-only <your-branch>
```

## Push to Deploy Branch

When this skill is invoked, it is allowed to run:

```powershell
git push origin <deploy-branch>
```

The following are **always forbidden**:

- `git push --force`
- `git push --force-with-lease`
- `git reset --hard`

## Triggering the Jenkins Build

### Option 1: Via Jenkins Web UI

1. Open the Jenkins Job page in your browser
2. Log in to Jenkins
3. If the Job has a branch parameter, set it to the deploy branch
4. Click **Build**

### Option 2: Via Script

Run the trigger script only when this skill is installed from the filesystem and the
`scripts/` directory is actually present on disk. If the skill was installed as plain
text instructions only, such as in `.cursorrules` or a knowledge base upload, the
script files will not exist and you should use the Jenkins Web UI flow instead.

**On Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1
```

**On macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py
```

Here `python3` simply means a Python 3 interpreter. If `python` in the current environment already points to Python 3, using `python` is also acceptable.

The script reads its defaults from `config.json` in the skill root directory.

Choose the script that matches the current platform:
1. Windows -> `trigger_jenkins_build.ps1`
2. macOS / Linux -> `trigger_jenkins_build.py`

The platform split matters because the PowerShell script relies on Windows-specific
credential handling, while the Python entrypoint is the portable path for macOS/Linux.

If the user explicitly requests a specific environment such as "部署到 test 环境" or
"deploy pre", switch to that environment's target branch instead of the default `dev`,
push to that branch, and pass the matching environment flag to the script so it can
load the correct Jenkins URL and credentials:
1. Check out that environment's target branch (e.g. `test` or `pre`) instead of `dev`.
2. Push your code to that branch.
3. Pass `-TargetEnv <env>` on PowerShell or `--target-env <env>` on Python so the script dynamically loads the correct Jenkins URL and credentials.

**Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py --target-env test
```

To individually override values at runtime:

**Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 `
  -TargetEnv "test" `
  -Username "<your-jenkins-username>" `
  -Branch "test"
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py \
  --target-env "test" \
  --username "<your-jenkins-username>" \
  --branch "test"
```

## Jenkins Token Setup

### Generate an API Token

1. Log in to Jenkins via browser
2. Navigate to your user profile
3. Open **Configure** or **Settings**
4. Find the **API Token** section
5. Click **Add new Token** and copy the value

### Securely Save your Jenkins API Token

**For Windows:**
Store the token in Windows Credential Manager (Generic Credentials):

1. Open **Credential Manager** (Windows)
2. Go to **Windows Credentials**
3. Click **Add a generic credential**
4. Fill in:
   - **Internet or network address**: the value you set in `config.json` → `credentialTarget` (e.g. `jenkins-api-auth-id`. Note: This is an arbitrary custom identifier you choose, not necessarily a URL. Just ensure it matches exactly)
   - **User name**: your Jenkins username
   - **Password**: the API Token you generated

**For macOS:**
Store the token in the system Keychain via Terminal:
```bash
security add-generic-password -s "jenkins-api-auth-id" -a "your-jenkins-username" -w "your-api-token"
```

**For Linux / CI Fallback:**
Set the environment variables before execution:
```bash
export JENKINS_USERNAME="your-jenkins-username"
export JENKINS_API_TOKEN="your-api-token"
```

## Windows Dependencies

If running on Windows and the `CredentialManager` PowerShell module is not installed, the script will automatically:

1. Install the `NuGet` package provider (CurrentUser scope)
2. Mark `PSGallery` as Trusted
3. Install the `CredentialManager` module (CurrentUser scope)
4. Continue execution

## Platform Behavior

- Windows keeps using `trigger_jenkins_build.ps1` so the existing CredentialManager auto-install flow remains unchanged
- macOS uses `trigger_jenkins_build.py`, which reads credentials from Keychain via the built-in `security` command
- Linux / CI uses `trigger_jenkins_build.py` with `JENKINS_USERNAME` and `JENKINS_API_TOKEN` as the fallback path

## Troubleshooting

### `git push` returns 403

- Your Git account may lack write access to the repository
- If using HTTPS, check your stored credentials
- If 2FA is enabled, you likely need a Personal Access Token (PAT)

### Jenkins returns 403

- Jenkins requires authentication — verify your credentials
- Check that the username and API Token in Credential Manager are correct
- Check that the token has not expired or been revoked

### Script cannot find credentials

- Ensure the credential target name matches `credentialTarget` in your `config.json`
- If using a custom target, pass `-CredentialTarget <name>` when running the script

### Merge conflicts occur during deployment

- If a Git merge conflict happens, the automated process will pause or fail
- Do not resolve source-code merge conflicts autonomously. Conflict resolution needs business context, and an incorrect automatic choice can silently introduce bugs into production. Hand the conflict back to the human developer instead
- Abort the in-progress merge/rebase immediately: `git merge --abort` or `git rebase --abort`
- Inform the user that manual conflict resolution is required
- The user will resolve conflicts in their IDE, commit, and then re-invoke this skill to complete the push and trigger
