# asdf-to11

[asdf](https://asdf-vm.com) plugin for [`to11`](https://github.com/to11ai/to11-cli) — the to11 CLI, which puts a company's skills on a developer's machine and runs their coding agent through the to11 gateway.

## Install

```bash
asdf plugin add to11 https://github.com/to11ai/asdf-to11
asdf install to11 latest
asdf set to11 latest        # or add `to11 <version>` to .tool-versions
to11 version
```

The tool is `to11` everywhere — the plugin name, `.tool-versions`, and the command. Binaries come from the releases in [to11ai/to11-cli](https://github.com/to11ai/to11-cli), which carries releases and no source.

## While to11-cli is private

Until that repository is public, both listing and downloading need a token with read access to it, and `jq` on `PATH`:

```bash
export GITHUB_API_TOKEN=$(gh auth token)
asdf install to11 latest
```

Without a token you get a single clear error rather than a hang or a bare 404. `GITHUB_TOKEN` is accepted as an alternative name. Once the repository is public no token is needed, and setting one only raises the GitHub API rate limit.

## Supported platforms

| | amd64 | arm64 |
|---|---|---|
| linux | ✅ | ✅ |
| darwin | ✅ | ✅ |

There is no Windows build: `to11 init` shells out to `stty` to hide credential input, so Windows needs a fix in the CLI before it can be published here.

## Versions

`asdf list all to11` reads the tags of `to11ai/to11-cli`, which are plain `v<semver>` — the monorepo's `cli-` prefix is stripped when a release is published. `latest` skips prereleases, so it never resolves to an `-rc` build.
