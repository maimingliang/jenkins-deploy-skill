---
name: jenkins-deploy-skill
description: >
  Use this skill whenever the user mentions deploying, pushing to Jenkins,
  triggering a build, or merging to a deploy branch such as dev, test, or pre.
  It automates "merge -> push -> Jenkins build" with secure credential handling
  across Windows, macOS, and Linux, and supports both legacy single-project and
  multi-project config layouts. Invoke it for requests like "帮我部署",
  "push 到 test 环境", "deploy pre", "发布 demo-admin 的 test 环境", or "触发 Jenkins 构建".
---

## Project Metadata

| Field | Value |
| Version | `1.2.1` |
| Author | `maiml` |
| Repository | [maimingliang/jenkins-deploy-skill](https://github.com/maimingliang/jenkins-deploy-skill) |
| Tags | `jenkins`, `deploy`, `ci-cd`, `git`, `devops` |

# Jenkins Deploy Skill

## Goal

- Integrate your current work into the correct upstream branch for the requested environment
- Push the target deploy branch to the remote repository
- Trigger a Jenkins Job build on that branch
- Branch, project, URL, and credentials can dynamically change based on the target project and environment

## Prerequisites

Before using this skill you need to:

1. Set up your `config.json` — copy `config.example.json` for single-project usage, or `config.multi-project.example.json` for multi-project usage
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

## Recommended Git Flow

Use these branch roles by default unless the repository already has a clearly different release convention:

> Note: `dev`, `test`, `pre`, and `gray` are only common examples. They are not fixed standards. Always follow the actual environment names and branch mapping defined in `config.json`.

- `dev`: integration environment
- `test`: promotion environment
- `pre`: promotion environment after `test`
- `gray` / production-like environments: do not automate by default

The Git target branch should come from the environment's `branch` setting in `config.json`.

- In the recommended single-project layout, use `defaultEnvironment: "dev"` and write `dev`, `test`, and `pre` explicitly under `environments`.
- In the multi-project layout, use `projects.<name>.environments.<env>.branch`.
- Root-level fields such as `branch`, `jenkinsBaseUrl`, and `jobName` are still supported in the legacy single-project format for backward compatibility.
- If a team uses `release/1.12.0` as the integration branch, simply set the `dev` environment's `branch` to `release/1.12.0`.

Default branch flow:

- Deploy `dev`: current personal branch -> the branch configured for `dev`
- Deploy `test`: the branch configured for `dev` -> the branch configured for `test`
- Deploy `pre`: the branch configured for `test` -> the branch configured for `pre`

This means `test` and `pre` are promotion steps by default. Do not merge a personal branch directly into `test` or `pre` unless the user explicitly asks for a chained release flow and the team already works that way.

## Auto-commit Rules

If the current personal branch contains uncommitted changes, this skill may create one controlled commit before deployment so the whole release can continue end to end.

Allowed:

- Auto-commit on the current personal branch before deployment

Not allowed:

- Auto-commit directly on `dev`, `test`, `pre`, or any environment branch
- Auto-commit when merge conflicts are in progress
- Auto-commit when the user has partially staged files
- Auto-commit sensitive files such as `.env`, private keys, or `secrets/`

Configuration:

- `gitFlow.autoCommitBeforeDeploy`: default `true`; allows one controlled commit on the current personal branch before deployment
- `gitFlow.allowCascadePromote`: default `true`; allows a chained release when the user asks for `test` or `pre` from a personal branch and the team works that way

## Git Execution Model

Before deploying, always refresh remote state first:

```powershell
git fetch origin
```

Use a temporary local deployment branch for each deployment instead of reusing the local `dev`, `test`, or `pre` branch.

Recommended flow:

1. Record the current source branch
2. If allowed and needed, auto-commit uncommitted changes on the current personal branch
3. `git fetch origin`
4. Create a temporary local branch from `origin/<target-branch>`
5. Merge the correct source branch into that temporary branch
6. Push with `git push origin HEAD:<target-branch>`
7. Trigger Jenkins only after the push succeeds
8. Switch back to the original branch and delete the temporary local branch

Example temporary branch name:

```text
codex/tmp-test-20260417-153000-abcd
```

## Merge Strategy

- For `dev` integration, a normal merge is acceptable
- For `test` and `pre` promotion, prefer `git merge --ff-only`
- If `ff-only` promotion fails, stop and tell the user to sync the upstream branch first

## Push to Deploy Branch

When this skill is invoked, it is allowed to run:

```powershell
git push origin HEAD:<deploy-branch>
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

The script reads its defaults from `config.json` in the skill root directory. The config can use either the legacy single-project layout or the multi-project layout with `defaultProject`, `projects.<name>.defaults`, and `projects.<name>.environments.<env>`.

The `gitFlow` block in `config.json` is for deployment workflow rules such as auto-commit and chained release behavior. The Jenkins trigger scripts still read only the Jenkins-related runtime fields.

Choose the script that matches the current platform:
1. Windows -> `trigger_jenkins_build.ps1`
2. macOS / Linux -> `trigger_jenkins_build.py`

The platform split matters because the PowerShell script relies on Windows-specific
credential handling, while the Python entrypoint is the portable path for macOS/Linux.

If the user explicitly requests a specific environment such as "部署到 test 环境" or
"deploy pre", use the branch flow above instead of always defaulting to `dev`, then
push the correct target branch and pass the matching environment flag to the script so
it can load the correct Jenkins URL and credentials:
1. Determine the correct upstream source branch for that environment.
2. Merge or promote into the requested target branch.
3. Push the target branch.
4. Pass `-TargetEnv <env>` on PowerShell or `--target-env <env>` on Python so the script dynamically loads the correct Jenkins URL and credentials.

If the user also specifies a project, such as "发布 demo-admin 的 test 环境" or
"deploy demo-service pre", keep the same flow and also pass the project flag:
1. Use the matching branch flow for that environment under the requested project.
2. Push the target branch for that environment.
3. Pass `-Project <project> -TargetEnv <env>` on PowerShell or `--project <project> --target-env <env>` on Python so the script loads the correct project-specific Jenkins settings.

If the user asks to deploy `test` while still sitting on a personal branch, default to strict mode:

1. Auto-commit the personal branch first when it is safe and appropriate.
2. Do not merge that personal branch directly into `test`.
3. Promote from the branch configured for `dev` into the branch configured for `test`.

Only use chained release mode when `gitFlow.allowCascadePromote` is `true`, the user clearly wants it, and the team already follows that convention:

1. Auto-commit the personal branch
2. Integrate it into the branch configured for `dev`
3. Push that upstream branch
4. Promote the upstream branch into `test`
5. Push `test`
6. Trigger Jenkins

**Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py --target-env test
```

**Windows (multi-project)**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -Project demo-admin -TargetEnv test
```

**macOS / Linux (multi-project)**
```bash
python3 ./scripts/trigger_jenkins_build.py --project demo-admin --target-env test
```

To individually override values at runtime:

**Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 `
  -Project "demo-admin" `
  -TargetEnv "test" `
  -Username "<your-jenkins-username>" `
  -Branch "test"
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py \
  --project "demo-admin" \
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
- Both scripts support the legacy single-project config format and the newer multi-project config format

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
