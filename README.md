# Informatica Secure Agent — Installation & PostgreSQL ODBC Setup

A practical, tested set of guides for installing the Informatica Intelligent Cloud Services (IICS / IDMC) **Secure Agent** and connecting it to **PostgreSQL** via **ODBC** — including the non-obvious fixes needed on a modern Linux host and a free IICS org.

## Contents

| Guide                                                              | Description                                                                                                                       |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| [01 – Secure Agent on Windows](01-secure-agent-install-windows.md) | Download, install, and register the agent on Windows 64-bit.                                                                      |
| [02 – Secure Agent on Linux](02-secure-agent-install-linux.md)     | Console-mode install on any x86-64 Linux host (generic commands).                                                                 |
| [03 – ODBC + PostgreSQL Setup](03-odbc-postgresql-setup.md)        | **Critical.** The definitive step-by-step to get an ODBC→PostgreSQL connection actually running, with the library and auth fixes. |

## SQL Scripts

Add your `.sql` files under a `sql/` folder (create the tables, sample data, and any join demos referenced in the guides).

```
.
├── README.md
├── 01-secure-agent-install-windows.md
├── 02-secure-agent-install-linux.md
├── 03-odbc-postgresql-setup.md
└── sql/
    └── (your SQL scripts here)
```

## Quick Start

1. Stand up a host — **Linux 64** or **Windows 64** .
2. Install and register the Secure Agent (guide 01 or 02).
3. Configure the ODBC → PostgreSQL connection (guide 03).
4. Build a mapping and run it; verify in **Monitor**.

## Key Gotchas (read before you start)

- **Start the agent only once** — duplicate starts cause a lock-file crash loop.
- **Give it 8 GB+ RAM** — the microservices are memory-hungry.
- **Modern Linux needs `libidn.so.11`** — symlink it if missing (guide 03, Step 7).
- **psqlODBC + SCRAM auth crashes the DTM** — use `trust` auth on `127.0.0.1` locally (guide 03, Step 6).
- **The agent reads ODBC config from its own folder** — not `/etc` (guide 03, Step 5).

## Disclaimer

These guides reflect a specific, tested setup (Secure Agent on an x86-64 Linux host with a local PostgreSQL, free IICS org). Paths, versions, and menu labels vary by agent build, OS, and IICS release. The `trust` auth step is intended for a local, non-exposed learning database only — never for shared or production systems.
