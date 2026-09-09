# asdf-to11

[asdf](https://asdf-vm.com) plugin for [`to11`](https://github.com/to11ai/to11-cli) — the to11 CLI.

## Install

```bash
asdf plugin add to11 https://github.com/to11ai/asdf-to11
asdf install to11 latest
asdf set to11 latest        # or add `to11 <version>` to .tool-versions
to11 version
```

## Supported platforms

| | amd64 | arm64 |
|---|---|---|
| linux | ✅ | ✅ |
| darwin | ✅ | ✅ |

## Versions

`asdf list all to11` reads the tags of `to11ai/to11-cli`, which are plain `v<semver>` — the monorepo's `cli-` prefix is stripped when a release is published. `latest` skips prereleases, so it never resolves to an `-rc` build.
