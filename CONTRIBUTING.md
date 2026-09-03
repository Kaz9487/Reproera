# Contributing

Contributions should keep Reproera useful on restricted and old Linux systems.

1. Do not introduce a runtime dependency on Python, Node.js, or a newer shell.
2. Keep the minimum shell baseline at Bash 4.2 unless a major release changes it.
3. Pin every source URL and SHA-256 digest.
4. Never add `sudo` or modify system package databases.
5. Add an offline test for parsing, planning, or control-flow changes.
6. Document whether compiler coverage is simulated or executed in a real image.

Run `bash tests/test.sh` before opening a pull request. Run ShellCheck when it is
available.
