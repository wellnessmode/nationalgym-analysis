#!/usr/bin/env python3
"""Post a build/analyze error log as a commit comment via GitHub API.

Usage: post-build-error.py <log_file> <title>
Env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA
"""
import json, os, sys, urllib.request

def main():
    log_file = sys.argv[1]
    title = sys.argv[2]
    log = open(log_file).read()[-6000:]
    body = f'## {title}\n\n```\n{log}\n```'
    payload = json.dumps({'body': body}).encode('utf-8')
    repo = os.environ['GITHUB_REPOSITORY']
    sha = os.environ['GITHUB_SHA']
    req = urllib.request.Request(
        f'https://api.github.com/repos/{repo}/commits/{sha}/comments',
        data=payload,
        headers={
            'Authorization': 'Bearer ' + os.environ['GITHUB_TOKEN'],
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
        },
        method='POST',
    )
    try:
        resp = urllib.request.urlopen(req)
        print(f'comment posted: {resp.status}')
    except Exception as e:
        print(f'comment failed: {e}')

if __name__ == '__main__':
    main()
