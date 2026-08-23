# Ubuntu VPS First Run Transcript

```text
$ sudo apt-get update
$ sudo apt-get install -y bash curl git ca-certificates
$ curl -fsSL https://raw.githubusercontent.com/smeltery/set-me-up-installer/main/install.sh | bash -s -- --profile vps --plan
This script will download 'smeltery/set-me-up-blueprint' on branch 'master'.
plan: machine profile vps
plan: submodule scope platform
plan: no changes applied
$ curl -fsSL https://raw.githubusercontent.com/smeltery/set-me-up-installer/main/install.sh | bash -s -- --profile vps
Detected 'set-me-up' version: debian.
Provisioning adapter preflight passed.
$ smu doctor --strict --json
{
  "ok": true,
  "strict": true
}
```
