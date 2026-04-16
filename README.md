# jenkins-deploy-skill

[English](#english) | [中文](#中文)

---

## English

An AI Agent skill/prompt that automates the "merge → push → trigger Jenkins build" workflow. It merges your feature branch into a deploy branch via Git and triggers a parameterised Jenkins build through the REST API.

### Features

- 🔀 **Git flow** — Safely merges and pushes to the deploy branch (force-push is forbidden)
- 🚀 **Jenkins trigger** — Fires a parameterised build via Jenkins REST API
- 🔐 **Secure credentials** — Supports Windows Credential Manager, macOS Keychain, and env-var fallback (no plaintext secrets)
- 📦 **Auto-install** — Automatically installs the `CredentialManager` PowerShell module if missing
- ⚙️ **Configurable** — All values driven by `config.json` with CLI overrides
- 🌍 **Multi-Environment** — Core inheritance pattern in `config.json` for environments like `dev`, `test`, `pre`
- 🛡️ **CSRF-safe** — Automatically fetches Jenkins crumb for CSRF protection

### Installation (For AI Assistants)

This skill is simply a collection of standard files. There is no heavy plugin to install.
1. Download or `git clone` this repository to a permanent location on your machine.
2. Tell your AI assistant how to use it by hooking `SKILL.md` into your project:
   - **Codex**: Place this entire downloaded folder into your global skills directory:
     - Windows: `%USERPROFILE%\.codex\skills\`
     - macOS/Linux: `~/.codex/skills/`
   - **Cursor/Windsurf**: Copy the contents of `SKILL.md` (excluding the YAML header) to a `.cursorrules` file in your target project's root. For a global skill, place it in:
     - Windows: `%USERPROFILE%\.cursorrules`
     - macOS/Linux: `~/.cursorrules` (Or via UI: Settings > General > Rules for AI)
   - **Claude Code (CLI)**: Copy the contents to a `.clauderc` file in your project's root. For a global skill, place it in:
     - Windows: `%USERPROFILE%\.clauderc`
     - macOS/Linux: `~/.clauderc`
   - **GitHub Copilot**: Copy the contents to `.github/copilot-instructions.md` in your project's root. For a global skill, place it in:
     - Windows: `%USERPROFILE%\.github\copilot-instructions.md`
     - macOS/Linux: `~/.github/copilot-instructions.md`
   - **Claude Projects / ChatGPT**: Upload `SKILL.md` directly into the Knowledge base or Custom Instructions.

### Prerequisites

Before getting started, verify your environment is ready:

```powershell
# Check PowerShell version (5.1+ required)
$PSVersionTable.PSVersion

# Check Git is installed and configured
git --version
git config --global user.name
git config --global user.email

# Verify your Git remote is set up (should show origin → your repo)
git remote -v
```

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

3. **Securely save your Jenkins API Token**:

   **For Windows:**
   - Open **Credential Manager** → **Windows Credentials** → **Add a generic credential**
   - **Target**: the `credentialTarget` from your config (e.g. `jenkins-api-auth-id`)
   - **Username**: your Jenkins username
   - **Password**: your Jenkins API Token

   **For macOS:**
   - Open Terminal and add it to your Keychain (matches your `credentialTarget`):
     ```bash
     security add-generic-password -s "jenkins-api-auth-id" -a "your-jenkins-username" -w "your-api-token"
     ```

   **For Linux / Fallback:**
   - Export environment variables before running:
     ```bash
     export JENKINS_USERNAME="your-jenkins-username"
     export JENKINS_API_TOKEN="your-api-token"
     ```

4. **Run the script**:

   ```powershell
   powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1
   ```

### CLI Parameters

All parameters are optional if set in `config.json`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ConfigFile` | Path to config JSON file | `../config.json` (relative to script) |
| `-TargetEnv` | The configuration environment to inherit from `config.json` | `""` |
| `-JenkinsBaseUrl` | Jenkins server URL | from config |
| `-JobName` | Jenkins job name | from config |
| `-Username` | Jenkins username (overrides Credential Manager) | from Credential Manager |
| `-ApiToken` | Jenkins API token (overrides Credential Manager) | from Credential Manager |
| `-CredentialTarget` | Windows Credential Manager target name | from config |
| `-Branch` | Branch to build | `dev` |
| `-BranchParamName` | Jenkins parameter name for branch | `BRANCH` |

### Project Structure

```
jenkins-deploy-skill/
├── SKILL.md                 # AI skill definition / prompt
├── README.md                # This file
├── LICENSE                  # MIT License
├── config.example.json      # Configuration template
├── .gitignore               # Ignores config.json (contains secrets)
├── CONTRIBUTING.md          # Contribution guide
└── scripts/
    └── trigger_jenkins_build.ps1   # Jenkins trigger script
```

### Advanced: Multi-Environment

If you use an internal Jenkins for `dev` and a cloud Jenkins for `test`/`pre`, define an `environments` block in your `config.json` (see `config.example.json` for syntax). 

When you ask the AI to "Deploy to test" using this Skill, the AI will automatically append the `-TargetEnv` parameter to route the build seamlessly based on your config:

```powershell
# Executed automatically by the AI skill (or manually if you prefer):
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

### Troubleshooting

#### Dealing with Merge Conflicts
As an automated AI skill, a Git merge conflict will interrupt the execution. If a conflict occurs during merging:
1. Issue `git merge --abort` or `git rebase --abort` to stop the AI's current attempt.
2. Resolve the conflicts manually in your preferred IDE.
3. Commit the resolved changes locally.
4. Invoke this skill again to push the code and trigger the Jenkins build.

### License

[MIT](./LICENSE)

---

## 中文

一个通用的 AI Agent Skill（系统提示词），自动化 "合并代码 → 推送 → 触发 Jenkins 构建" 工作流。通过 Git 将特性分支合并到部署分支，并通过 REST API 触发 Jenkins 参数化构建。

### 特性

- 🔀 **Git 流程** — 安全地合并并推送到部署分支（禁止 force-push）
- 🚀 **Jenkins 触发** — 通过 REST API 触发参数化构建
- 🔐 **安全凭据** — 支持从 Windows 凭据管理器、macOS 钥匙串读取，或由环境变量兜底（拒绝明文密码）
- 📦 **自动安装** — 自动安装 `CredentialManager` PowerShell 模块
- ⚙️ **可配置** — 所有参数通过 `config.json` 驱动，支持命令行覆盖
- 🌍 **多环境支持** — 配置文件支持 `environments` 参数继承机制（如独立配置 `dev` / `test`）
- 🛡️ **CSRF 安全** — 自动获取 Jenkins crumb

### 安装指南 (适配各大 AI 工具)

这个 Skill 本质上是一套“脚本 + AI 提示词”，无需安装笨重的各类专有环境插件：
1. 找一个本地固定的目录，`git clone` 或直接下载本仓库的代码。
2. 在您**实际写代码的目标项目**里，给您的 AI 助手提供这份说明书入口：
   - **Codex 用户**：直接将刚下载的整个文件夹，放置到全局的 Codex 技能库目录下：
     - Windows: `%USERPROFILE%\.codex\skills\`
     - macOS/Linux: `~/.codex/skills/`
   - **Cursor / Windsurf 用户**：复制 `SKILL.md` 的内容（可删掉最顶部的 `---` YAML 头），然后在目标项目根目录新建并存为 `.cursorrules` 文件。若需设置为全局技能：
     - Windows: 存为 `%USERPROFILE%\.cursorrules`
     - macOS/Linux: 存为 `~/.cursorrules` （或通过界面填入 Settings > General > Rules for AI）
   - **Claude Code (CLI) 用户**：复制内容存为目标项目根目录下的 `.clauderc` 文件。若需设置为全局技能：
     - Windows: 存为 `%USERPROFILE%\.clauderc`
     - macOS/Linux: 存为 `~/.clauderc`
   - **GitHub Copilot 用户**：存为目标项目根目录下针对 Copilot 的 `.github/copilot-instructions.md` 文件。若需设置为全局技能：
     - Windows: 存为 `%USERPROFILE%\.github\copilot-instructions.md`
     - macOS/Linux: 存为 `~/.github/copilot-instructions.md`
   - **Claude Projects 等其他 Web AI**：新建 Project 时，直接将 `SKILL.md` 作为一个 Knowledge 文件上传，或者将内容填入 Custom Instructions 即可。

### 环境检查

开始之前，请先确认你的环境已就绪：

```powershell
# 检查 PowerShell 版本（需要 5.1+）
$PSVersionTable.PSVersion

# 检查 Git 是否已安装并配置
git --version
git config --global user.name
git config --global user.email

# 确认 Git remote 已设置（应显示 origin → 你的仓库地址）
git remote -v
```

### 快速开始

1. **复制配置模板**

   ```powershell
   Copy-Item config.example.json config.json
   ```

2. **编辑 `config.json`**，填入你的 Jenkins 信息：

   ```json
   {
     "jenkinsBaseUrl": "http://你的Jenkins地址:8080",
     "jobName": "你的Job名称",
     "credentialTarget": "jenkins-api-auth-id",
     "branch": "dev",
     "branchParamName": "BRANCH"
   }
   ```

3. **安全配置 Jenkins API Token**：

   **对于 Windows 用户：**
   - 打开 **凭据管理器** → **Windows 凭据** → **添加普通凭据**
   - **目标名**：与 `config.json` 中的 `credentialTarget` 一致（例如：`jenkins-api-auth-id`。无需填写真实网址）
   - **用户名**：你的 Jenkins 用户名
   - **密码**：你的 Jenkins API Token

   **对于 macOS 用户：**
   - 打开您的终端，使用内置命令将凭据安全存入钥匙串：
     ```bash
     security add-generic-password -s "jenkins-api-auth-id" -a "你的用户名" -w "你的API-Token"
     ```
     *(这里的 `-s` 必须与 config 中的 `credentialTarget` 保持一致)*

   **对于 Linux / 通用终端环境：**
   - 若不使用任何本地凭据管理，可通过拉起环境变量兜底：
     ```bash
     export JENKINS_USERNAME="你的用户名"
     export JENKINS_API_TOKEN="你的API-Token"
     ```

4. **运行脚本**：

   ```powershell
   powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1
   ```

### 高级用法：多环境部署

如果您在不同的环境对应了不同的 Jenkins 节点（例如内网发 `dev`，云端发 `test`），您只要在 `config.json` 中配置 `environments` 节点（参考 `config.example.json` 设置覆盖规则）。

运行时，**您只需在聊天框对 AI 说“帮我发 test 环境”**，AI 就会在后台自动带上 `-TargetEnv` 参数来智能切换云端或内网环境：

```powershell
# 以下底层的命令会由 AI Skill 自动调用（您依然可以手动执行它）：
powershell -ExecutionPolicy Bypass -File ./scripts/trigger_jenkins_build.ps1 -TargetEnv test
```

### 常见问题与排错

#### 如何处理合并冲突 (Merge Conflicts)？
由于这是一个由 AI 辅助的自动化 Skill，一旦遇到 Git 合并冲突，自动流程将会中断。遇到冲突时的推荐做法：
1. 执行 `git merge --abort` 或 `git rebase --abort` 终止当前的合并尝试。
2. 在您的 IDE (如 VSCode / IDE) 中手动、安全地解决冲突代码。
3. 本地提交解决完冲突后的正确代码。
4. **再次调用此 Skill**，让 AI 完成后续的 Push 及触发 Jenkins 流程。

### 许可证

[MIT](./LICENSE)
