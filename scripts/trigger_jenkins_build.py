#!/usr/bin/env python3
# Copyright (c) 2026 maiml (maimingliang [at] gmail.com)
# Licensed under the MIT License
"""
跨平台 Jenkins 触发脚本。
- Windows：转调现有 PowerShell 脚本，保留 CredentialManager 自动安装与原有行为。
- macOS：直接读取 Keychain，并调用 Jenkins REST API。
- Linux/CI：优先使用命令行参数，其次使用环境变量。
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import platform
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Mapping, Optional, Sequence, Tuple
from urllib import error, parse, request


SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
SKILL_ROOT = SCRIPT_DIR.parent


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="跨平台 Jenkins 构建触发器（Windows 会转调 PowerShell 版本）。"
    )
    parser.add_argument("-ConfigFile", "--config-file", dest="config_file")
    parser.add_argument("-Project", "--project", dest="project")
    parser.add_argument("-TargetEnv", "--target-env", dest="target_env")
    parser.add_argument("-JenkinsBaseUrl", "--jenkins-base-url", dest="jenkins_base_url")
    parser.add_argument("-JobName", "--job-name", dest="job_name")
    parser.add_argument("-Username", "--username", dest="username")
    parser.add_argument("-ApiToken", "--api-token", dest="api_token")
    parser.add_argument("-CredentialTarget", "--credential-target", dest="credential_target")
    parser.add_argument("-Branch", "--branch", dest="branch")
    parser.add_argument("-BranchParamName", "--branch-param-name", dest="branch_param_name")
    return parser


def warn(message: str) -> None:
    print(f"WARNING: {message}", file=sys.stderr)


def default_config_path() -> Path:
    return SKILL_ROOT / "config.json"


def strip_config_comments(text: str) -> str:
    """
    Strips // and /* */ comments from a string, respecting quoted strings.
    """
    regex = r'("(?:\\.|[^"\\])*")|(?P<comment>//.*|/\*.*?\*/)'

    def substitute(match: re.Match) -> str:
        if match.group("comment"):
            return ""
        return match.group(1)

    return re.sub(regex, substitute, text, flags=re.DOTALL)


def load_config(path_value: Optional[str]) -> Dict[str, Any]:
    path = Path(path_value).expanduser() if path_value else default_config_path()
    if not path.exists():
        warn(f"Config file not found at '{path}'. Using command-line parameters only.")
        return {}

    try:
        raw = path.read_text(encoding="utf-8-sig")
        clean = strip_config_comments(raw)
        parsed = json.loads(clean)
    except Exception as exc:  # noqa: BLE001
        warn(f"Failed to parse config file: {exc}")
        return {}

    if not isinstance(parsed, dict):
        warn("Config file root must be a JSON object. Using command-line parameters only.")
        return {}

    return parsed


def resolve_param(cli_value: Optional[str], config_value: Any, default: str) -> str:
    if cli_value is not None and str(cli_value).strip():
        return str(cli_value)
    if config_value is not None and str(config_value).strip():
        return str(config_value)
    return default


def mapping_or_empty(value: Any) -> Dict[str, Any]:
    if isinstance(value, Mapping):
        return dict(value)
    return {}


def select_project_name(config: Mapping[str, Any], requested_project: Optional[str]) -> str:
    projects = mapping_or_empty(config.get("projects"))
    if not projects:
        raise RuntimeError("Multi-project config is missing the 'projects' block.")

    if requested_project:
        if requested_project in projects:
            return requested_project
        raise RuntimeError(f"Project '{requested_project}' was not found in config.json.")

    default_project = str(config.get("defaultProject") or "").strip()
    if default_project:
        if default_project in projects:
            return default_project
        raise RuntimeError(f"defaultProject '{default_project}' was not found in config.json.")

    if len(projects) == 1:
        return next(iter(projects))

    raise RuntimeError(
        "Project is required for multi-project config. Set defaultProject in config.json "
        "or pass -Project/--project."
    )


def select_environment_name(
    project_name: str,
    project_config: Mapping[str, Any],
    requested_target_env: Optional[str],
) -> Optional[str]:
    environments = mapping_or_empty(project_config.get("environments"))

    if requested_target_env:
        if not environments or requested_target_env not in environments:
            raise RuntimeError(
                f"Target environment '{requested_target_env}' was not found under project "
                f"'{project_name}'."
            )
        return requested_target_env

    default_environment = str(project_config.get("defaultEnvironment") or "").strip()
    if default_environment:
        if default_environment in environments:
            return default_environment
        raise RuntimeError(
            f"defaultEnvironment '{default_environment}' was not found under project "
            f"'{project_name}'."
        )

    if "dev" in environments:
        return "dev"
    if len(environments) == 1:
        return next(iter(environments))
    return None


def resolve_project_defaults(project_config: Mapping[str, Any]) -> Dict[str, Any]:
    resolved: Dict[str, Any] = {}
    for key in (
        "jenkinsBaseUrl",
        "jobName",
        "credentialTarget",
        "branch",
        "branchParamName",
    ):
        if key in project_config:
            resolved[key] = project_config[key]

    resolved.update(mapping_or_empty(project_config.get("defaults")))
    return resolved


def select_legacy_environment_name(
    config: Mapping[str, Any],
    requested_target_env: Optional[str],
) -> Optional[str]:
    environments = mapping_or_empty(config.get("environments"))

    if requested_target_env:
        if not environments or requested_target_env not in environments:
            raise RuntimeError(
                f"Target environment '{requested_target_env}' was not found in legacy config."
            )
        return requested_target_env

    default_environment = str(config.get("defaultEnvironment") or "").strip()
    if default_environment:
        if default_environment in environments:
            return default_environment
        raise RuntimeError(
            f"defaultEnvironment '{default_environment}' was not found in legacy config."
        )

    if "dev" in environments:
        return "dev"
    if len(environments) == 1:
        return next(iter(environments))
    return None


def resolve_legacy_config(config: Mapping[str, Any], target_env: Optional[str]) -> Dict[str, Any]:
    merged = dict(config)
    selected_env = select_legacy_environment_name(config, target_env)
    if not selected_env:
        return merged

    environments = mapping_or_empty(config.get("environments"))
    env_config = mapping_or_empty(environments.get(selected_env))
    print(f"Applying environment overrides for: {selected_env}")
    merged.update(env_config)
    merged["targetEnv"] = selected_env
    return merged


def resolve_multi_project_config(
    config: Mapping[str, Any],
    requested_project: Optional[str],
    requested_target_env: Optional[str],
) -> Dict[str, Any]:
    projects = mapping_or_empty(config.get("projects"))
    project_name = select_project_name(config, requested_project)
    project_config = mapping_or_empty(projects.get(project_name))
    if not project_config:
        raise RuntimeError(f"Project '{project_name}' was not found in config.json.")

    print(f"Using project: {project_name}")
    resolved = resolve_project_defaults(project_config)

    target_env_name = select_environment_name(project_name, project_config, requested_target_env)
    if target_env_name:
        environments = mapping_or_empty(project_config.get("environments"))
        env_config = mapping_or_empty(environments.get(target_env_name))
        print(f"Applying environment overrides for: {target_env_name}")
        resolved.update(env_config)
        resolved["targetEnv"] = target_env_name

    resolved["projectName"] = project_name
    return resolved


def resolve_effective_config(
    config: Mapping[str, Any],
    requested_project: Optional[str],
    requested_target_env: Optional[str],
) -> Dict[str, Any]:
    projects = mapping_or_empty(config.get("projects"))
    if projects:
        return resolve_multi_project_config(config, requested_project, requested_target_env)

    if requested_project:
        warn(
            f"Project '{requested_project}' was ignored because config.json is using the "
            "legacy single-project format."
        )
    return resolve_legacy_config(config, requested_target_env)


def resolve_macos_credential(target: str) -> Tuple[Optional[str], Optional[str]]:
    token_process = subprocess.run(
        ["security", "find-generic-password", "-s", target, "-w"],
        capture_output=True,
        text=True,
        check=False,
    )
    token = token_process.stdout.strip() if token_process.returncode == 0 else None

    dump_process = subprocess.run(
        ["security", "find-generic-password", "-s", target],
        capture_output=True,
        text=True,
        check=False,
    )
    username = None
    if dump_process.returncode == 0:
        match = re.search(r'"acct"\s*<blob>="([^"]+)"', dump_process.stdout)
        if match:
            username = match.group(1)
        else:
            warn(
                f"macOS Keychain: Could not parse username for '{target}'. "
                "Falling back to JENKINS_USERNAME env var."
            )

    return username, token


def resolve_credential(
    target: Optional[str],
    input_username: Optional[str],
    input_token: Optional[str],
) -> Tuple[str, str]:
    username = (input_username or "").strip()
    token = (input_token or "").strip()

    if username and token:
        return username, token

    if platform.system() == "Darwin" and target:
        keychain_username, keychain_token = resolve_macos_credential(target)
        if not username and keychain_username:
            username = keychain_username
        if not token and keychain_token:
            token = keychain_token

    if not username:
        username = os.getenv("JENKINS_USERNAME", "").strip()
    if not token:
        token = os.getenv("JENKINS_API_TOKEN", "").strip()

    if not username or not token:
        raise RuntimeError(
            "Jenkins credential is incomplete. On macOS, store it in Keychain; "
            "otherwise set JENKINS_USERNAME and JENKINS_API_TOKEN, or pass -Username/-ApiToken."
        )

    return username, token


def new_basic_auth_header(user: str, token: str) -> Dict[str, str]:
    encoded = base64.b64encode(f"{user}:{token}".encode("utf-8")).decode("ascii")
    return {"Authorization": f"Basic {encoded}"}


def http_json(url: str, headers: Optional[Mapping[str, str]] = None, timeout: int = 20) -> Dict[str, Any]:
    req = request.Request(url=url, headers=dict(headers or {}), method="GET")
    with request.urlopen(req, timeout=timeout) as response:
        payload = response.read().decode("utf-8")
    parsed = json.loads(payload)
    if not isinstance(parsed, dict):
        raise ValueError("Expected a JSON object response.")
    return parsed


def http_post(
    url: str,
    headers: Optional[Mapping[str, str]] = None,
    body: Optional[Mapping[str, str]] = None,
    timeout: int = 30,
) -> None:
    data = None
    if body:
        data = parse.urlencode(body).encode("utf-8")
    req = request.Request(url=url, data=data, headers=dict(headers or {}), method="POST")
    with request.urlopen(req, timeout=timeout):
        return


def get_jenkins_crumb(base_url: str, auth_headers: Mapping[str, str]) -> Dict[str, str]:
    crumb_url = f"{base_url.rstrip('/')}/crumbIssuer/api/json"
    try:
        response = http_json(crumb_url, headers=auth_headers, timeout=20)
    except Exception:  # noqa: BLE001
        return {}

    crumb_field = str(response.get("crumbRequestField") or "").strip()
    crumb_value = str(response.get("crumb") or "").strip()
    if not crumb_field or not crumb_value:
        return {}

    return {crumb_field: crumb_value}


def powershell_command_name() -> Optional[str]:
    for candidate in ("powershell", "pwsh"):
        result = subprocess.run(
            [candidate, "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            return candidate
    return None


def translate_args_for_powershell(original_args: Sequence[str]) -> Sequence[str]:
    arg_map = {
        "--config-file": "-ConfigFile",
        "--project": "-Project",
        "--target-env": "-TargetEnv",
        "--jenkins-base-url": "-JenkinsBaseUrl",
        "--job-name": "-JobName",
        "--username": "-Username",
        "--api-token": "-ApiToken",
        "--credential-target": "-CredentialTarget",
        "--branch": "-Branch",
        "--branch-param-name": "-BranchParamName",
    }
    return [arg_map.get(arg, arg) for arg in original_args]


def delegate_to_powershell(original_args: Sequence[str]) -> int:
    command_name = powershell_command_name()
    if not command_name:
        print(
            "Windows requires PowerShell to run trigger_jenkins_build.ps1, "
            "but neither 'powershell' nor 'pwsh' was found in PATH.",
            file=sys.stderr,
        )
        return 1

    ps_script = SCRIPT_DIR / "trigger_jenkins_build.ps1"
    command = [
        command_name,
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ps_script),
        *translate_args_for_powershell(original_args),
    ]
    completed = subprocess.run(command, check=False)
    return completed.returncode


def validate_required(name: str, value: str, hint: str) -> None:
    if not value.strip():
        raise RuntimeError(f"{name} is required. {hint}")


def main(argv: Sequence[str]) -> int:
    if "-h" in argv or "--help" in argv:
        parser = build_parser()
        parser.print_help()
        return 0

    if platform.system() == "Windows":
        return delegate_to_powershell(argv)

    parser = build_parser()
    args = parser.parse_args(argv)

    config = resolve_effective_config(load_config(args.config_file), args.project, args.target_env)

    resolved_jenkins_base_url = resolve_param(args.jenkins_base_url, config.get("jenkinsBaseUrl"), "")
    resolved_job_name = resolve_param(args.job_name, config.get("jobName"), "")
    resolved_credential_target = resolve_param(
        args.credential_target, config.get("credentialTarget"), ""
    )
    resolved_branch = resolve_param(args.branch, config.get("branch"), "dev")
    resolved_branch_param_name = resolve_param(
        args.branch_param_name, config.get("branchParamName"), "BRANCH"
    )

    validate_required(
        "JenkinsBaseUrl",
        resolved_jenkins_base_url,
        "Set it in config.json or pass -JenkinsBaseUrl.",
    )
    validate_required("JobName", resolved_job_name, "Set it in config.json or pass -JobName.")

    username, api_token = resolve_credential(
        resolved_credential_target,
        args.username,
        args.api_token,
    )
    auth_headers = new_basic_auth_header(username, api_token)
    crumb_headers = get_jenkins_crumb(resolved_jenkins_base_url, auth_headers)
    headers = {**auth_headers, **crumb_headers}

    base_url = resolved_jenkins_base_url.rstrip("/")
    build_with_params_url = f"{base_url}/job/{resolved_job_name}/buildWithParameters"
    build_url = f"{base_url}/job/{resolved_job_name}/build"

    print(
        "Trigger Jenkins build: "
        f"{resolved_jenkins_base_url} / job={resolved_job_name} / "
        f"{resolved_branch_param_name}={resolved_branch} / user={username}"
    )

    try:
        http_post(
            build_with_params_url,
            headers=headers,
            body={resolved_branch_param_name: resolved_branch},
            timeout=30,
        )
        print("Triggered buildWithParameters successfully.")
        return 0
    except (error.HTTPError, error.URLError, OSError, ValueError) as exc:
        warn(f"buildWithParameters failed, falling back to build. Error: {exc}")

    http_post(build_url, headers=headers, timeout=30)
    print("Triggered build successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
