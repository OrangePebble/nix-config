If a shell command is unavailable, run it with Nix comma (`, <command>`); do not install it.

Use `/tmp/pi` as the dedicated disposable workspace for temporary artifacts, experiments, generated files, and test fixtures.

Prefer the `read` tool with its line offset and limit for reading file ranges. Do not use `sed`, `awk`, Perl, or other interpreters solely to print lines. If Bash is necessary, use `head -n END -- FILE` for lines 1 through END, or `tail -n +START -- FILE | head -n COUNT` for an inclusive line range.
