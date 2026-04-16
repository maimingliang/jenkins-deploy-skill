# jenkins-deploy-skill

[English](#english) | [中文](#中文)

---

## English

An AI Agent skill/prompt that automates the "merge -> push -> trigger Jenkins build" workflow. It merges your feature branch into a deploy branch via Git and triggers a parameterised Jenkins build through the REST API.

### Features

- 🔀 **Git flow** — safely merges and pushes to the deploy branch, with force-push forbidden
- 🚀 **Jenkins trigger** — fires a parameterised build via Jenkins REST API
- 🔐 **Secure credentials** — supports Windows Credential Manager, macOS Keychain, and environment-variable fallback
- 📦 **Auto-install (Windows)** — automatically installs the `CredentialManager` PowerShell module if missing
- ⚙️ **Configurable** — all values are driven by `config.json` with CLI overrides
- 🌍 **Multi-environment** — supports an inheritance pattern in `config.json` for environments like `dev`, `test`, and `pre`
- 🛡️ **CSRF-safe** — automatically fetches Jenkins crumb for CSRF protection

### Installation (For AI Assistants)

#### Install By Chat

If your AI assistant supports installing skills directly from a repository URL, you can simply say this in chat:

```text
https://github.com/maimingliang/jenkins-deploy-skill skill
```

#### Manual Installation

1. Download or `git clone` this repository to a permanent location on your machine.
2. Hook `SKILL.md` into your AI assistant in the target project where you actually write code:
   - **Codex**: place this entire folder into your global skills directory
     - Windows: `%USERPROFILE%\.codex\skills\`
     - macOS/Linux: `~/.codex/skills/`
   - **Cursor / Windsurf**: copy the contents of `SKILL.md` to `.cursorrules`
     - Windows: `%USERPROFILE%\.cursorrules`
     - macOS/Linux: `~/.cursorrules`
   - **Claude Code (CLI)**: copy the contents to `.clauderc`
     - Windows: `%USERPROFILE%\.clauderc`
     - macOS/Linux: `~/.clauderc`
   - **GitHub Copilot**: copy the contents to `.github/copilot-instructions.md`
     - Windows: `%USERPROFILE%\.github\copilot-instructions.md`
     - macOS/Linux: `~/.github/copilot-instructions.md`
   - **Claude Projects / ChatGPT**: upload `SKILL.md` into the knowledge base or custom instructions

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

### Quick Start

1. **Copy the config template**

   ```powershell
   Copy-Item config.example.json config.json
   ```

2. **Edit `config.json`** with your Jenkins details:

   ```json
   {
     "jenkinsBaseUrl": "http://your-jenkins-server:8080",
     "jobName": "your-job-name",
     "credentialTarget": "jenkins-api-auth-id",
     "branch": "dev",
     "branchParamName": "BRANCH"
   }
   ```

3. **Securely save your Jenkins API Token**

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

4. **Run the script**

   **Windows**
   ```powershell
   powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1
   ```

   **macOS / Linux**
   ```bash
   python3 ./scripts/trigger_jenkins_build.py
   ```

### CLI Parameters

Both scripts support the same parameter names. All parameters are optional if they are already set in `config.json`.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ConfigFile` | Path to config JSON file | `../config.json` relative to script |
| `-TargetEnv` | Configuration environment to inherit from `config.json` | `""` |
| `-JenkinsBaseUrl` | Jenkins server URL | from config |
| `-JobName` | Jenkins job name | from config |
| `-Username` | Jenkins username, overrides local credential lookup | from local credential |
| `-ApiToken` | Jenkins API token, overrides local credential lookup | from local credential |
| `-CredentialTarget` | Target name in Windows Credential Manager or macOS Keychain | from config |
| `-Branch` | Branch to build | `dev` |
| `-BranchParamName` | Jenkins parameter name for the branch | `BRANCH` |

### Project Structure

```text
jenkins-deploy-skill/
|-- SKILL.md
|-- README.md
|-- LICENSE
|-- config.example.json
|-- .gitignore
|-- CONTRIBUTING.md
`-- scripts/
    |-- trigger_jenkins_build.ps1   # Windows trigger script
    `-- trigger_jenkins_build.py    # macOS/Linux trigger script
```

### Advanced: Multi-Environment

If you map different environments to different Jenkins nodes, for example internal Jenkins for `dev` and cloud Jenkins for `test`, you only need to configure the `environments` block in `config.json` and follow the override pattern shown in `config.example.json`.

At runtime, you can simply tell the AI something like "deploy to test". The AI will automatically append `-TargetEnv` in the background and switch to the correct internal or cloud environment.

**Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py -TargetEnv test
```

### Troubleshooting

#### Dealing with Merge Conflicts

As an automated AI skill, a Git merge conflict should interrupt the flow. If a conflict occurs:

1. Run `git merge --abort` or `git rebase --abort`.
2. Resolve the conflict manually in your IDE.
3. Commit the resolved changes locally.
4. Invoke the skill again to continue the push and Jenkins trigger flow.

### License

[MIT](./LICENSE)

---

## 中文

这是一个通用的 AI Agent Skill，用来自动化“合并代码 -> 推送分支 -> 触发 Jenkins 构建”的工作流。它会通过 Git 将你的功能分支合并到部署分支，并通过 REST API 触发 Jenkins 参数化构建。

### 特性

- 🔀 **Git 流程** — 安全地合并并推送到部署分支，严格禁止 force push
- 🚀 **Jenkins 触发** — 通过 REST API 触发参数化构建
- 🔐 **安全凭据** — 支持 Windows Credential Manager、macOS Keychain 和环境变量兜底
- 📦 **自动安装 (Windows)** — 缺少 `CredentialManager` PowerShell 模块时会自动安装
- ⚙️ **可配置** — 所有参数由 `config.json` 驱动，并支持命令行覆盖
- 🌍 **多环境支持** — 支持在 `config.json` 中为 `dev`、`test`、`pre` 等环境做继承覆盖
- 🛡️ **CSRF 安全** — 自动获取 Jenkins crumb

### 安装指南（适配各大 AI 工具）

#### 聊天安装

如果你的 AI 助手支持直接通过仓库地址安装 skill，你只需要在聊天框里这样说：

```text
https://github.com/maimingliang/jenkins-deploy-skill skill
```

#### 手动安装

1. 将本仓库下载或 `git clone` 到机器上的固定目录。
2. 在你实际开发的目标项目里，把 `SKILL.md` 接入你的 AI 助手：
   - **Codex**：将整个目录放入全局技能目录
     - Windows: `%USERPROFILE%\.codex\skills\`
     - macOS/Linux: `~/.codex/skills/`
   - **Cursor / Windsurf**：复制 `SKILL.md` 内容到 `.cursorrules`
     - Windows: `%USERPROFILE%\.cursorrules`
     - macOS/Linux: `~/.cursorrules`
   - **Claude Code (CLI)**：复制内容到 `.clauderc`
     - Windows: `%USERPROFILE%\.clauderc`
     - macOS/Linux: `~/.clauderc`
   - **GitHub Copilot**：复制内容到 `.github/copilot-instructions.md`
     - Windows: `%USERPROFILE%\.github\copilot-instructions.md`
     - macOS/Linux: `~/.github/copilot-instructions.md`
   - **Claude Projects / ChatGPT**：直接上传 `SKILL.md` 到知识库，或填入自定义指令

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

### 快速开始

1. **复制配置模板**

   ```powershell
   Copy-Item config.example.json config.json
   ```

2. **编辑 `config.json`**，填入 Jenkins 信息：

   ```json
   {
     "jenkinsBaseUrl": "http://your-jenkins-server:8080",
     "jobName": "your-job-name",
     "credentialTarget": "jenkins-api-auth-id",
     "branch": "dev",
     "branchParamName": "BRANCH"
   }
   ```

3. **安全保存 Jenkins API Token**

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

4. **运行脚本**

   **Windows**
   ```powershell
   powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1
   ```

   **macOS / Linux**
   ```bash
   python3 ./scripts/trigger_jenkins_build.py
   ```

### CLI 参数

两套脚本支持相同的参数名。如果这些值已经写入 `config.json`，运行时都可以省略。

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-ConfigFile` | 配置文件路径 | 相对脚本的 `../config.json` |
| `-TargetEnv` | 从 `config.json` 继承的环境名 | `""` |
| `-JenkinsBaseUrl` | Jenkins 服务地址 | 读取配置 |
| `-JobName` | Jenkins Job 名称 | 读取配置 |
| `-Username` | Jenkins 用户名，优先于本地凭据读取 | 读取本地凭据 |
| `-ApiToken` | Jenkins API Token，优先于本地凭据读取 | 读取本地凭据 |
| `-CredentialTarget` | Windows Credential Manager 或 macOS Keychain 中的目标名称 | 读取配置 |
| `-Branch` | 要构建的分支 | `dev` |
| `-BranchParamName` | Jenkins 中分支参数名 | `BRANCH` |

### 项目结构

```text
jenkins-deploy-skill/
|-- SKILL.md
|-- README.md
|-- LICENSE
|-- config.example.json
|-- .gitignore
|-- CONTRIBUTING.md
`-- scripts/
    |-- trigger_jenkins_build.ps1   # Windows 触发脚本
    `-- trigger_jenkins_build.py    # macOS/Linux 触发脚本
```

### 高级用法：多环境部署

如果您在不同的环境对应了不同的 Jenkins 节点，例如内网发 `dev`，云端发 `test`，您只要在 `config.json` 中配置 `environments` 节点，并参考 `config.example.json` 里的覆盖规则即可。

运行时，您只需在聊天框对 AI 说“帮我发 test 环境”，AI 就会在后台自动带上 `-TargetEnv` 参数，智能切换到正确的内网或云端环境。

**Windows**
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

**macOS / Linux**
```bash
python3 ./scripts/trigger_jenkins_build.py -TargetEnv test
```

### 常见问题与排错

#### 如何处理合并冲突

作为自动化 AI Skill，一旦遇到 Git 合并冲突，流程就应该暂停。推荐处理方式：

1. 执行 `git merge --abort` 或 `git rebase --abort`。
2. 在 IDE 中手动解决冲突。
3. 将解决后的代码在本地提交。
4. 再次调用这个 Skill，继续后续的 Push 和 Jenkins 触发流程。

### 许可证

[MIT](./LICENSE)
