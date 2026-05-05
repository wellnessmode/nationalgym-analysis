#!/usr/bin/env python3
"""Commit a build log file to the `ci-logs` branch via GitHub Contents API.
Usable from a sandbox that can reach api.github.com but not blob storage.

Env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA, RUN_ID, LOG_FILE
"""
import base64
import json
import os
import sys
import urllib.request
import urllib.error


def github_request(method, url, data=None):
    body = None if data is None else json.dumps(data).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            'Authorization': 'Bearer ' + os.environ['GITHUB_TOKEN'],
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
        },
        method=method,
    )
    try:
        resp = urllib.request.urlopen(req)
        return resp.status, resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', errors='replace')
    except Exception as e:
        return 0, str(e)


def main():
    repo = os.environ['GITHUB_REPOSITORY']
    sha = os.environ['GITHUB_SHA']
    run_id = os.environ['RUN_ID']
    log_path = os.environ['LOG_FILE']

    if not os.path.exists(log_path):
        print(f'log file not found: {log_path}')
        sys.exit(0)

    with open(log_path, 'rb') as f:
        log_bytes = f.read()

    # Truncate from the end if too large (GitHub contents API limit ~ 100MB but
    # we want a manageable size — keep last 64 KB)
    if len(log_bytes) > 64 * 1024:
        log_bytes = log_bytes[-64 * 1024:]

    content_b64 = base64.b64encode(log_bytes).decode('ascii')
    path_in_repo = f'ci-logs/{run_id}.log'

    # Ensure ci-logs branch exists. Try to create from current sha; ignore if exists.
    code, body = github_request(
        'POST',
        f'https://api.github.com/repos/{repo}/git/refs',
        {'ref': 'refs/heads/ci-logs', 'sha': sha},
    )
    print(f'create branch attempt: {code}')
    if code not in (201, 422):  # 422 = already exists
        print(f'create branch body: {body[:200]}')

    # PUT contents
    code, body = github_request(
        'PUT',
        f'https://api.github.com/repos/{repo}/contents/{path_in_repo}',
        {
            'message': f'ci: log for run {run_id}',
            'content': content_b64,
            'branch': 'ci-logs',
        },
    )
    print(f'put contents: {code} ({path_in_repo})')
    if code not in (200, 201):
        print(f'response: {body[:600]}')


if __name__ == '__main__':
    main()
