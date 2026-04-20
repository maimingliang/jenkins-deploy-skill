# jenkins-deploy-skill

![Version](https://img.shields.io/github/v/tag/maimingliang/jenkins-deploy-skill?label=version&style=flat-square)
![License](https://img.shields.io/github/license/maimingliang/jenkins-deploy-skill?style=flat-square)
![Repo Size](https://img.shields.io/github/repo-size/maimingliang/jenkins-deploy-skill?style=flat-square)


[English](#english) | [简体中文](#简体中文)

---

## English

An AI Agent skill/prompt that automates the "merge -> push -> trigger Jenkins build" workflow. It merges your feature branch into a deploy branch via Git and triggers a parameterised Jenkins build through the REST API.


### Prerequisites

Before getting started, verify your environment is ready:

```powershell
# Check PowerShell version (required when running the Windows script)
$PSVersionTable.PSVersion

# Check Git is installed and configured
git --version
git config --global user.name
git config --global user.email

# Verify your Git remote is set up
git remote -v
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

5. Save the file and quickly verify the final content.

   **Windows (PowerShell):**
   ```powershell
   Get-Content .\config.json
   ```

   **macOS / Linux (Bash):**
   ```bash
   cat ./config.json
   ```

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
Copy-Item config.multi-project.example.json config.json
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -Project demo-admin -TargetEnv test
```

**macOS / Linux**
```bash
cp config.multi-project.example.json config.json
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

---

## 中文

这是一个通用的 AI Agent Skill，用来自动化“合并代码 -> 推送分支 -> 触发 Jenkins 构建”的工作流。它会通过 Git 将你的功能分支合并到部署分支，并通过 REST API 触发 Jenkins 参数化构建。


### 环境检查

开始之前，请先确认环境已就绪：

```powershell
# 检查 PowerShell 版本（Windows 运行脚本时需要）
$PSVersionTable.PSVersion

# 检查 Git 是否已安装并配置
git --version
git config --global user.name
git config --global user.email

# 确认 Git remote 已设置
git remote -v
```

```bash
# macOS / Linux 建议额外确认 Python 可用
python3 --version
```

这里的 `python3` 仅表示 Python 3 解释器；如果你的环境里 `python` 已经指向 Python 3，也可以直接用 `python`。

### 安全凭据配置

在运行脚本之前，请先以安全的方式准备好 Jenkins API Token：

**Windows**
- 打开 **凭据管理器** -> **Windows 凭据** -> **添加普通凭据**
- **目标名称**：填写 `config.json` 中的 `credentialTarget`
- **用户名**：你的 Jenkins 用户名
- **密码**：你的 Jenkins API Token

**macOS**
- 打开终端，将凭据保存到系统钥匙串：
  ```bash
  security add-generic-password -s "jenkins-api-auth-id" -a "your-jenkins-username" -w "your-api-token"
  ```
- 这里的 `-s` 必须与 `config.json` 中的 `credentialTarget` 一致

**Linux / CI / 通用兜底**
- 执行前设置环境变量：
  ```bash
  export JENKINS_USERNAME="your-jenkins-username"
  export JENKINS_API_TOKEN="your-api-token"
  ```

### 安装指南（适配各大 AI 工具）

#### 1. 自动安装 (推荐)

如果您的 AI 助手（如 Codex、Claude Code）支持直接通过仓库地址安装 Skill，只需在对话框中发送以下安装指令：

> [!TIP]
> 请完整复制下方指令（确保包含末尾的 `skill` 关键字）并直接发送：

```text
https://github.com/maimingliang/jenkins-deploy-skill skill
```

<details>
<summary>手动安装</summary>

1. 将本仓库下载或 `git clone` 到机器上的固定目录。
2. 在你实际开发的目标项目里，把 `SKILL.md` 接入你正在使用的助手：
   - **Codex**：将整个目录放入全局技能目录
     - Windows: `%USERPROFILE%\.codex\skills\`
     - macOS/Linux: `~/.codex/skills/`
   - **Cursor / Windsurf**：复制 `SKILL.md` 内容到 `.cursorrules`
     - Windows: `%USERPROFILE%\.cursorrules`
     - macOS/Linux: `~/.cursorrules`
   - **Claude Code (CLI)**：将整个目录放入 Claude 技能目录
     - Windows: `%USERPROFILE%\.claude\skills\`
     - macOS/Linux: `~/.claude/skills/`
   - **GitHub Copilot**：复制内容到 `.github/copilot-instructions.md`
     - Windows: `%USERPROFILE%\.github\copilot-instructions.md`
     - macOS/Linux: `~/.github/copilot-instructions.md`
   - **Claude Projects / ChatGPT**：直接上传 `SKILL.md` 到知识库，或填入自定义指令

如果你拿不准该选哪种方式，优先用上面的“聊天安装”。如果你更想自己手动接入，再看下面这些方式：

- 如果你还拿不准怎么选，优先从 **Codex** 或 **Claude Code** 开始。这两种方式通常可以直接使用仓库自带的 `scripts/`，额外准备工作最少。
- **文件系统安装**：例如 Codex、Claude 技能目录。推荐这种方式，因为它会把 `scripts/` 一起放到本地，可以直接调用脚本。
- **纯文本安装**：例如 `.cursorrules`、Copilot 指令文件、知识库上传。这种方式可以保留工作流说明，但不会自动带上本地 `scripts/`。如果你还想走脚本触发，就需要把脚本额外复制到本地工具目录；否则请按照 `SKILL.md` 中的 Jenkins Web UI 流程来用。

</details>

### 快速开始

如果你现在只想先接通一个 Jenkins 项目，建议从这里开始。所有命令都请在 `jenkins-deploy-skill` 根目录下执行。

本节介绍最为常用的单项目轻型配置（参考 `config.example.json`）。建议在 `environments` 中显式定义 `dev`、`test`、`pre` 等环境块，以便于直观维护与切换。如需通过单个 Skill 同时管理多个独立项目，请参阅下文的 [高级用法：多项目与多环境部署](#高级用法多项目与多环境部署)。

#### 方式一：手动修改

1. 先根据模板生成 `config.json`。

   **Windows (PowerShell):**
   ```powershell
   Copy-Item config.example.json config.json
   ```

   **macOS / Linux (Bash):**
   ```bash
   cp config.example.json config.json
   ```

2. 使用你喜欢的编辑器在 `jenkins-deploy-skill` 根目录中打开 `config.json`，例如 VS Code、记事本或其他文本编辑器。

3. 将示例占位值替换成你自己的 Jenkins 配置。模板本身保持标准 JSON，这样在编辑器、校验工具和自动化场景里都更稳定。

4. 关键字段如下：

   | 字段 | 说明 | 常见取值 |
   |------|------|----------|
   | `defaultEnvironment` | 没有明确指定环境时默认使用的环境 | `dev` |
   | `branchParamName` | Jenkins 中分支参数名 | `BRANCH` |
   | `environments` | `dev`、`test`、`pre` 等环境块；每个环境都可以有自己的 Jenkins 地址、Job、分支和 `credentialTarget` | 参考 `config.example.json` |
   | `gitFlow` | 可选的发布流程规则：<br>• `autoCommitBeforeDeploy`: 部署前自动提交工作区修改<br>• `allowCascadePromote`: 允许从工作分支一键“直发” test/pre（自动完成集成与同步） | `{"autoCommitBeforeDeploy": true, "allowCascadePromote": true}` |

5. 保存文件后，使用下面的命令快速确认最终配置内容。

   **Windows (PowerShell):**
   ```powershell
   Get-Content .\config.json
   ```

   **macOS / Linux (Bash):**
   ```bash
   cat ./config.json
   ```

<details>
<summary>方式二：命令行生成 config.json</summary>

1. 如果你更习惯待在终端里，也可以直接把配置文件写出来，而不是打开编辑器逐个修改。

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

2. 检查 `config.json` 是否已经生成，并确认配置内容符合预期。

   **Windows (PowerShell):**
   ```powershell
   Get-Content .\config.json
   ```

   **macOS / Linux (Bash):**
   ```bash
   cat ./config.json
   ```

</details>

#### 操作示例

完成上述配置后，最直观的验证方式就是直接在聊天框中向 AI 发出部署指令：

```text
帮我部署到 dev 环境
```

如果你已经配置了多环境，也可以直接说：

```text
帮我部署到 test 环境
```

一次成功的执行，通常会按顺序完成这三件事：

1. 按目标环境把正确的 Git 分支做集成或同步
2. 把目标发布分支推到远端仓库
3. 触发对应环境的 Jenkins Job

随后你应该能在 Jenkins 里看到对应 Job 新出现一条排队中或运行中的构建记录。这就是最直观的成功标志。


### 推荐的 Git 发布流程

这个 skill 最适合配合一套职责清晰的环境分支来使用。

> 说明：`dev`、`test`、`pre`、`gray` 只是常见示例，不是固定标准。不同团队完全可以使用自己的环境命名。这个 skill 的实际行为由 `config.json` 中各环境的配置决定，尤其是每个环境自己的 `branch`、Jenkins 地址、Job 和凭据设置。

#### 环境职责

| 环境 | 角色 | 默认接收来源 |
|------|------|--------------|
| `dev` | **内网开发环境** (Dev) | 你的工作分支 (如 `feature/login`) |
| `test` | **测试环境** (Test/QA) | `dev` 对应的分支 |
| `pre` | **预发布环境** (Pre-release) | `test` 对应的分支 |
| `gray` | **灰度环境** (Alpha/Gray) | 默认手动处理 |

#### 同步链路

```text
feature/login ──► dev ──► test ──► pre ──► (gray: manual)
     ▲               │         │
     │               │         │
  auto-commit     sync   sync
  (if needed)   (ff-only)  (ff-only)
```

- **发布 `dev`**：将功能分支代码**集成**（Merge）到开发环境。
- **发布 `test`**：将开发环境的成果**同步**（Promote）到测试环境进行验证。
- **发布 `pre`**：将测试通过的版本**同步**（Promote）到预发布环境准备上线。

> ⚠️ 默认情况下，`test` 和 `pre` 均为**同步（Sync）**阶段，原则上不直接接收个人工作分支。

#### 分支映射逻辑

Git 目标分支的选取规则取决于 `config.json` 的组织结构：

- **单项目模式**：在 `environments` 下为各个环境显式配置 `branch` 字段。
- **多项目模式**：通过 `projects.<name>.environments.<env>.branch` 路径进行定义。

系统将根据当前目标环境，自动选取对应的分支进行代码同步与发布。

#### 未提交修改怎么处理

如果当前工作分支还有未提交修改，skill 可以先在当前工作分支上做一次受控自动提交，这样整条发布链路可以一次跑完。它不会直接在 `dev`、`test`、`pre` 这些长期存在的环境分支上制造脏提交。

实际执行时，skill 会通过临时本地分支保护你的长期环境分支，也避免改写你自己的工作分支历史。

#### `gitFlow` 配置项

| 配置项 | 默认值 | 作用 |
|--------|--------|------|
| `autoCommitBeforeDeploy` | `true` | 允许在发布前对当前工作分支做一次受控自动提交 |
| `allowCascadePromote` | `true` | 允许串联发布。比如你在 `feature/login` 上直接说“发 test”，skill 会先集成到 `dev`，再从 `dev` 同步到 `test` |



### 高级用法：多项目与多环境部署

当单个 Skill 需要同时维护多个独立项目时，建议采用多项目配置方案。

#### 配置步骤

1. **启用模板**：将 `config.multi-project.example.json` 另存为 `config.json`。

   **Windows (PowerShell):**
   ```powershell
   Copy-Item config.multi-project.example.json config.json
   ```
   
   **macOS / Linux (Bash):**
   ```bash
   cp config.multi-project.example.json config.json
   ```

2. **定义项目与环境**：在 `projects` 对象下定义各个项目及其独有的 `environments`。每个项目、每个环境都可以有自己独立的 Jenkins 地址、Job、分支和 `credentialTarget`。
3. **设置默认值**：利用 `defaultProject` 指定缺省项目，并在 `projects.<name>.defaults` 中定义各环境通用的 Jenkins 地址或凭据标识。

#### 调用示例

配置完成后，AI 助手将具备跨项目识别能力。您可以直接要求：

- “帮我发 demo-admin 的 test 环境”
- “deploy demo-service to pre”

系统将根据项目名称自动定位至正确的项目配置与环境分支。

<details>
<summary>如果你是手动执行脚本</summary>

下面这些参数说明，只针对直接运行 `trigger_jenkins_build.ps1` 或 `trigger_jenkins_build.py` 的用户。

##### 项目怎么选

| 场景 | 结果 |
|------|------|
| 显式传了 `--project` 或 `-Project` | 优先使用这个项目 |
| 没有显式传项目 | 使用 `defaultProject` |
| 配置里实际上只有一个项目 | 脚本可以自动识别 |
| 配置里有多个项目、又没有 `defaultProject` | 需要明确指定项目名 |

##### 配置文件怎么选

| 场景 | 结果 |
|------|------|
| 显式传了 `--config-file` 或 `-ConfigFile` | 使用这个文件 |
| 没有显式传配置文件 | 只读取 `config.json` |
| 目录里同时存在 `config.multi-project.json` | 不会自动切过去 |
| 想使用 `config.multi-project.example.json` | 先复制或改名成 `config.json`，或者通过 `--config-file` 显式指定 |

##### 环境怎么选

| 场景 | 结果 |
|------|------|
| 显式传了 `--target-env` 或 `-TargetEnv` | 优先使用这个环境 |
| 没有显式传环境，且配置了 `defaultEnvironment` | 使用 `defaultEnvironment` |
| 没有 `defaultEnvironment`，但存在 `dev` | 默认走 `dev` |

##### 手动执行脚本示例

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
Copy-Item config.multi-project.example.json config.json
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -Project demo-admin -TargetEnv test
```

**macOS / Linux**
```bash
cp config.multi-project.example.json config.json
python3 ./scripts/trigger_jenkins_build.py --project demo-admin --target-env test
```

</details>

### 常见问题与排错

#### 如何处理合并冲突

一旦遇到 Git 合并冲突，流程就会暂停。推荐处理方式：

1. 执行 `git merge --abort` 或 `git rebase --abort`。
2. 在 IDE 中手动解决冲突。
3. 将解决后的代码在本地提交。
4. 再次调用这个 Skill，继续后续的 Push 和 Jenkins 触发流程。

#### 代码已经 Push 成功，但 Jenkins 触发失败怎么办

- 即使 Jenkins 没有成功启动，代码也可能已经在目标分支上了。
- 这种情况下，默认不需要回滚 Git。
- 先解决 Jenkins 侧的问题，比如凭据失效、crumb 接口不可用、网络不通等。
- 之后重新调用这个 skill，或者手动触发同一个 Jenkins Job 即可。

#### Jenkins 认证失败怎么办

- 先确认 `credentialTarget` 和 Windows Credential Manager 或 macOS Keychain 里保存的目标名称完全一致。
- 确认 Jenkins 用户名和 API Token 仍然有效。
- 如果你走的是环境变量兜底，确认当前终端会话里已经设置了 `JENKINS_USERNAME` 和 `JENKINS_API_TOKEN`。

#### CSRF crumb 相关错误怎么办

- 先确认 `jenkinsBaseUrl` 是否写对，并且当前机器可以访问。
- 确认对应 Jenkins 用户有权限访问 crumb issuer 接口。
- 如果 Jenkins 前面有反向代理，再检查代理层是否丢掉了必要请求头。

#### `config.json` 路径不对或读错文件怎么办

- 默认情况下，脚本只会读取 `config.json`。
- 如果你想用别的配置文件，请显式传 `--config-file` 或 `-ConfigFile`。
- `config.multi-project.example.json` 只是模板，只有复制或显式指定之后才会真正生效。

#### 受保护分支导致 Push 失败怎么办

- 这个 skill 默认假设目标发布分支允许直接 push。
- 如果仓库对 `dev`、`test`、`pre` 等分支开启了保护规则，即使本地合并成功，push 也可能被拒绝。
- 这时就需要切回你们团队自己的 PR 流程，或者调整对应发布分支的保护策略。

#### `--ff-only` 同步失败怎么办

- 这通常表示上游分支已经前进了，当前这次同步不再是 fast-forward。
- 先把上游分支同步到最新，再重新执行 skill。
- 比如常见的 `dev -> test` 同步，可以先执行：

```bash
git fetch origin
git checkout dev
git pull --ff-only
```

- 如果失败发生在“个人工作分支 -> dev”的集成阶段，就先按团队约定把你的工作分支同步到最新的 `origin/dev`，解决冲突后再重新发布。

### 许可证

[MIT](./LICENSE)

## Project Metadata

| Field | Value |
|-------|-------|
| Version | `1.2.2` |
| Author | `maiml` |
| Repository | [maimingliang/jenkins-deploy-skill](https://github.com/maimingliang/jenkins-deploy-skill) |
| Tags | `jenkins`, `deploy`, `ci-cd`, `git`, `devops` |
