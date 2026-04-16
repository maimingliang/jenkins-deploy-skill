---
name: jenkins-deploy-skill
version: 1.0.0
author: maiml
repository: https://github.com/maimingliang/jenkins-deploy-skill
tags: [jenkins, deploy, ci-cd, git, devops]
description: >
  An AI skill for deploying code via Git merge and triggering Jenkins builds.
  Merges your working branch into a target branch, then triggers a Jenkins
  parameterised build. Supports reading credentials from Windows Credential Manager, 
  macOS Keychain, Environment Variables, and has built-in multi-environment inheritance.
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

Run the trigger script from the skill directory:

```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1
```

The script reads its defaults from `config.json` in the skill root directory.

If the USER explicitly requests to deploy to a specific environment (e.g., "部署到 test 环境" or "deploy pre"), you **MUST**:
1. Check out that environment's target branch (e.g. `test` or `pre`) instead of `dev`.
2. Push your code to that branch.
3. Pass the `-TargetEnv <env>` parameter to the script so it dynamically loads the correct Jenkins URL and credentials.

```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

To individually override values at runtime:

```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 `
  -TargetEnv "test" `
  -Username "<your-jenkins-username>" `
  -Branch "test"
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
- **CRITICAL: You (the AI) MUST NOT attempt to resolve source-code merge conflicts autonomously.** Incorrect conflict resolution can silently introduce bugs into production. Always defer to the human developer
- Abort the in-progress merge/rebase immediately: `git merge --abort` or `git rebase --abort`
- Inform the user that manual conflict resolution is required
- The user will resolve conflicts in their IDE, commit, and then re-invoke this skill to complete the push and trigger
