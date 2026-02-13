# whatelse

whatelse is a lightweight Linux system administration tool that analyzes a systemd service before it is stopped or modified.

It helps prevent dangerous assumptions by automatically checking reverse dependencies, target membership, service state, and active runtime connections.

The tool is read-only and does not modify the system.

---

## Purpose

Stopping the wrong service in production can cause outages.

whatelse provides a clear, structured view of:

* Which systemd units depend on a service
* Whether the service is part of critical targets
* Whether the service is currently active
* Active listening ports and connection counts (if `lsof` is available)

This allows administrators to make informed decisions before stopping or restarting services.

---

## Supported Systems

Designed to work out of the box on:

* RHEL
* Debian
* Ubuntu
* Arch Linux

No manual configuration required.

---

## Requirements

Minimal required tools:

* bash
* systemctl
* ps
* awk
* grep
* sort
* lsof (optional, for runtime connection analysis)

All of these are available by default on supported distributions.

---

## Installation

Clone the repository:

```
git clone <repo-url>
cd whatelse
chmod +x whatelse.sh
```

### Optional: Make it available globally

To run `whatelse` like a built-in command without `./`:

```bash
sudo cp whatelse.sh /usr/local/bin/whatelse
sudo chmod +x /usr/local/bin/whatelse
```

After this, you can run:

```
whatelse postgresql
```

No `./` and no directory navigation required.

---

## Usage

Basic usage:

```
whatelse <service-name>
```

Examples:

```
whatelse nginx
whatelse postgresql
```

---

### Output to File

Output format is automatically determined by file extension.

Text output:

```
whatelse nginx --output report.txt
```

JSON output:

```
whatelse nginx --output report.json
```

If no output file is specified, results are printed to stdout.

---

## What It Checks

For a given service, whatelse reports:

* Service existence and state
* Reverse systemd dependencies
* Target membership
* Active main PID (if running)
* Listening ports and active connections (if `lsof` is available)

The tool does not attempt to score severity or make automated decisions. It is designed to provide visibility, not policy enforcement.

---

## Safety

* Read-only tool
* Does not stop, restart, or modify services
* Does not change system configuration
* Safe to run on production systems

---

## Limitations

* Requires systemd-based systems
* Runtime connection analysis depends on `lsof`
* Does not analyze application-level dependencies

