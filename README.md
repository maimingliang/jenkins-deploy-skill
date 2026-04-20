# jenkins-deploy-skill

![Version](https://img.shields.io/github/v/tag/maimingliang/jenkins-deploy-skill?label=version&style=flat-square)
![License](https://img.shields.io/github/license/maimingliang/jenkins-deploy-skill?style=flat-square)
![Repo Size](https://img.shields.io/github/repo-size/maimingliang/jenkins-deploy-skill?style=flat-square)

[English](https://github.com/maimingliang/jenkins-deploy-skill/wiki/English) | [简体中文](https://github.com/maimingliang/jenkins-deploy-skill/wiki/简体中文) | [Wiki 技术文档](https://github.com/maimingliang/jenkins-deploy-skill/wiki)

---

> [!CAUTION]
> **免责声明 (Disclaimer)**：本工具仅建议用于开发和测试环境。由于自动化合并与 Jenkins 触发涉及核心业务流程，**严禁直接用于生产环境 (Production) 发布**。作者不对因使用本工具导致的任何生产事故、损失或数据丢失负责。

# 使用指南 (Usage Guide)

## 简介

最近在用 AI 开发项目的时候，修改完代码要发版，麻烦的要死：
切终端 → `git checkout dev` → 合并 feature 分支 → push → 打开 Jenkins → 找到 Job → "Build with Parameters" → 填分支名 → 点构建 → 等队列。

一天发个三五次，**单是上下文切换就能耗掉半小时**。就想：为啥不让 AI 也直接把我发布，于是就有了这个 skill。如果你要发版，只需要对 AI 说：
> **"帮我部署到 dev 环境"**

---



## 1. 环境准备 (Environment Check)

在开始之前，确保你的 Git 全局配置已经正确设置（特别是用户名和邮箱），因为 Skill 会基于这些信息进行代码提交。

![Git Check](./docs/assets/step1_git_check.png)

---

## 2. Jenkins 凭据准备 (Jenkins API Token)

你需要生成一个 Jenkins API Token 作为身份验证密钥。

1. 登录 Jenkins，点击右上角用户名 -> **设置 (Settings)**。
2. 找到 **API Token** 模块，点击 **生成 (Generate)**。
3. **记录下这个 Token**，它将作为后续存储在系统凭据管理器中的“密码”。

![Jenkins Token](./docs/assets/step2_jenkins_token.png)

---

## 3. Skill 安装 (Installation)

如果你使用的是支持 URL 安装的 AI 助手（如 Codex、Claude Code），可以直接发送安装链接。

指令示例：
`安装 https://github.com/maimingliang/jenkins-deploy-skill skill`

![Install Skill](./docs/assets/step3_install.png)

---

## 4. 配置文件初始化 (Configuration)

### 4.1 创建 config.json
将项目根目录下的 `config.example.json` 复制并重命名为 `config.json`。
> [!IMPORTANT]
> Skill 运行时优先读取并只认 `config.json`。

![Config File](./docs/assets/step4_config_file.png)

### 4.2 映射系统凭据 (Credential Mapping)
这是最关键的一步。你需要将 `config.json` 中的 `credentialTarget` 字段与系统凭据管理器中的“网络地址”进行对应。

*   **左图**：在 Windows 凭据管理器中添加“普通凭据”。
*   **右图**：在 `config.json` 中配置对应的环境参数。

![Credential Mapping](./docs/assets/step5_credential_mapping.png)

---

## 5. 示例 (Example)

配置完成后，你可以尝试对 AI 助手说：`发布dev`。

AI 会自动完成以下操作：
1. **自动 Fetch** 远端代码。
2. 在本地创建名为 `tmp-deploy/...` 的**隔离分支**。
3. 如果有未提交改动，自动执行一次**受控提交**。
4. **Push** 到远端发布分支。
5. **触发 Jenkins** 任务。

![Usage Example](./docs/assets/step6_usage.png)

---

## 更多参考
*   详细的参数说明与技术细节请查看：
    *   [English Technical Documentation (Wiki)](https://github.com/maimingliang/jenkins-deploy-skill/wiki/English)
    *   [简体中文技术文档 (Wiki)](https://github.com/maimingliang/jenkins-deploy-skill/wiki/简体中文)

---

## License

[MIT](./LICENSE)
