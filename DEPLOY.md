# Deploying the Jay Squad Sec Agent

Read this whole page once before running anything. It's short.

## What you are deploying

An **alert-only monitoring agent**. It watches process starts/exits, network
peers, code signatures (Windows), suspicious executable locations, deleted
binaries and autorun changes, scores them with the risk engine, and writes
alerts to `jaysec_alerts.log`. It **never kills, suspends, or blocks
anything**, so it cannot break your PC.

Keep Windows Defender (or your Linux security tooling) ON. This agent is a
second pair of eyes, not a replacement — it has no kernel sensors yet, so it
cannot see memory injection or credential theft (see Coverage below).

## Windows

1. Install Rust: https://rustup.rs (default options, ~2 min, no admin needed).
2. Double-click `build_windows.cmd` in this folder (or run it in a terminal).
3. Run `target\release\agent.exe` in a terminal. Leave it running.
4. Stop any time with Ctrl+C. Uninstall = delete the folder. The agent
   installs nothing, changes no settings, and adds no autoruns itself.

Building locally (instead of downloading a prebuilt .exe) is deliberate:
locally built binaries are far less likely to be false-flagged by Defender,
and you can read every line of what you're running.

Optional — start with Windows (only after a few days of happy testing):
Task Scheduler -> Create Basic Task -> At log on -> Start a program ->
`agent.exe`, "Start in" = this folder.

## Linux

```
cargo build --release --bin agent     # or use the prebuilt binary if included
./target/release/agent
```

Optional systemd user service (`~/.config/systemd/user/jaysec.service`):

```
[Unit]
Description=Jay Squad Sec agent (alert-only)

[Service]
ExecStart=%h/jay-squad-sec/target/release/agent --log %h/jaysec_alerts.log
Nice=10

[Install]
WantedBy=default.target
```

Then: `systemctl --user enable --now jaysec`.

## Keeping it lightweight

- Default 2s poll interval; raise it with `--interval-ms 5000` for even less
  overhead. The agent also self-throttles: if a poll ever runs long it backs
  off automatically (up to 10s), and speeds back up when the machine is quiet.
- Deep inspection (network attribution, signature checks) applies only to
  processes started *after* the agent — the baseline set stays at L0 with
  near-zero cost. This is the adaptive-observation principle doing its job.
- Signature checks are capped at 8 per poll and cached per path.
- Expect roughly: idle CPU well under 1%, RAM ~10–20 MB (Linux), slightly
  more on Windows while a PowerShell signature check runs.

## Reading alerts

`jaysec_alerts.log` lines look like:

```
1784972900 t+5s [policy] .hidden_updater (d888b1e1) Allow -> Restrict (risk 50.0)
1784972900 t+5s [ALERT] .hidden_updater would lose network access (alert-only mode)
```

"would" = what enforcement WOULD have done. Your move when you see one:
look up the process (Task Manager / `ps`), check its path and publisher,
and kill it yourself if it's hostile. Risk decays (30s half-life), so a
one-off oddity de-escalates on its own — repeated alerts are the signal.

## Coverage — honest version

| Sees | Doesn't see (needs kernel phase) |
| ---- | -------------------------------- |
| New/exited processes | RWX memory allocations |
| Executables in temp/Downloads | Remote thread injection |
| Binaries deleted while running | Credential store access |
| Unsigned executables (Windows) | File contents / encryption bursts |
| Established TCP peers | Short-lived processes (<1 poll) |
| New autorun/persistence entries | Rootkits hiding from /proc & APIs |

A process that does nothing but look normal will not be flagged — that's
true of every behavioural system. Defense in depth: agent + OS antivirus +
updates + backups.

## Tuning (the fun part)

- Weights: `src/risk.rs` (`base_score`) — after a week of logs, raise what
  fired on real badness, lower what fired on your own tools.
- Thresholds: `action_for` in the same file.
- Suspicious paths: `suspicious_path` in `src/telemetry.rs` (add your own
  staging dirs; remove Downloads if it's too chatty for you).
- Rebuild after any change: `cargo build --release --bin agent`.

## Roadmap to real enforcement

Alert-only -> (weeks of tuned, quiet logs) -> suspend-at-Suspend-tier ->
kernel sensors (eBPF on Linux via aya; ETW on Windows) -> the full v2.0
capability enforcement. Don't skip steps: enforcement with untuned weights
is how a security tool becomes the thing that kills your PC.
