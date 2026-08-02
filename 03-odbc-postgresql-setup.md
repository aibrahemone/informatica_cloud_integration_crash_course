# Configuring ODBC for PostgreSQL on a Linux Secure Agent (Definitive Guide)

This is the procedure to connect an Informatica Secure Agent (Linux) to a **PostgreSQL** database using an **ODBC** connection — the connection type available on a **free IICS org**.

> **You will not need this steps if you are on Windows, creating ODBC connections on windows is straight forward.**

It includes the three non-obvious fixes that block a working setup on a modern Linux host:

1. The Secure Agent reads ODBC config from its **own** `odbcinst.ini` location, not `/etc`.
2. The DTM engine needs an **old system library** (`libidn.so.11`) that new distros don't ship.
3. The open-source PostgreSQL ODBC driver **segfaults during SCRAM password auth** because of an OpenSSL conflict with the agent's bundled crypto — fixed by using `trust` auth locally.

> **Assumptions:** Agent installed at `~/infaagent` and **Up and Running**. PostgreSQL running on the **same VM** as the agent. Adjust hostnames/paths if your setup differs.

---

## Step 0 — Install PostgreSQL (skip if you already have a DB)

On Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
```

Set a password and create a test database:

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'admin123';"
sudo -u postgres psql -c "CREATE DATABASE testdb;"
```

Create a simple table to test with:

```bash
sudo -u postgres psql -d postgres -c "CREATE TABLE emp (id int, name text); INSERT INTO emp VALUES (1,'Ahmed'),(2,'Sara');"
```

---

## Step 1 — Install the PostgreSQL ODBC driver + unixODBC

```bash
sudo apt update
sudo apt install -y odbc-postgresql unixodbc
```

Find the driver files (note the exact paths for your system):

```bash
ls -l /usr/lib/x86_64-linux-gnu/odbc/
# Expect: psqlodbca.so  (ANSI)  and  psqlodbcw.so  (Unicode)
```

Check which driver names got registered:

```bash
odbcinst -q -d
# Expect:
# [PostgreSQL ANSI]
# [PostgreSQL Unicode]
```

> **Key point:** the registered driver name is **`PostgreSQL Unicode`** (not plain `PostgreSQL`). Use that exact name in the DSN. The Unicode driver's shared object is **`psqlodbcw.so`** (the `w` = wide/Unicode).

---

## Step 2 — Register the driver in `odbcinst.ini`

The `odbc-postgresql` package usually writes `/etc/odbcinst.ini` automatically. Verify it:

```bash
cat /etc/odbcinst.ini
```

It should contain a section like:

```ini
[PostgreSQL Unicode]
Description = PostgreSQL ODBC driver (Unicode version)
Driver      = /usr/lib/x86_64-linux-gnu/odbc/psqlodbcw.so
Setup       = /usr/lib/x86_64-linux-gnu/odbc/libodbcpsqlS.so
```

If it's missing, create it (match the real path from Step 1).

---

## Step 3 — Create the DSN in `odbc.ini`

> **Terminal paste warning:** browser SSH terminals can mangle multi-line/heredoc pastes (keys end up merged onto one line). Use the single `printf` command below, which is paste-safe. **Verify with `cat` afterward.**

```bash
printf '[PostgresDSN]\nDescription = Postgres test\nDriver = PostgreSQL Unicode\nServername = 127.0.0.1\nPort = 5432\nDatabase = postgres\nUsername = postgres\nPassword = admin123\n' | sudo tee /etc/odbc.ini
```

Verify each key is on its own line and the driver reads `PostgreSQL Unicode`:

```bash
cat /etc/odbc.ini
```

> **Use `127.0.0.1`, not `localhost`** — this matters for the auth fix in Step 6.

---

## Step 4 — Test the DSN with `isql` (OS-level check)

```bash
isql -v PostgresDSN postgres admin123
```

- Success = a `SQL>` prompt. Type `quit` to exit. **Do not continue until this works.**
- `[IM002] Data source name not found` = the DSN or driver name doesn't resolve. Recheck:
  - DSN name matches `[PostgresDSN]` exactly (case-sensitive).
  - `Driver = PostgreSQL Unicode` matches a `[PostgreSQL Unicode]` section in `odbcinst.ini`.
  - Run `odbcinst -j` to see which files unixODBC actually reads.

---

## Step 5 — Point the **Secure Agent** at the ODBC config (critical)

The agent's DTM process does **not** read `/etc/odbcinst.ini`. It resolves `ODBCINST` and `ODBCSYSINI` to its **own install root**. Confirm by checking the running Data Integration Server's environment:

```bash
ps -ef | grep -i Data_Integration_Server | grep -v grep      # get the PID
sudo cat /proc/<PID>/environ | tr '\0' '\n' | grep -i odbc
```

You will typically see:

```
ODBCINI=/etc/odbc.ini
ODBCINST=/home/<user>/infaagent/odbcinst.ini
ODBCSYSINI=/home/<user>/infaagent/
```

So the agent reads the **DSN** from `/etc/odbc.ini` but the **driver registration** from `~/infaagent/odbcinst.ini`. Put both files where the agent looks:

```bash
cp /etc/odbc.ini      ~/infaagent/odbc.ini
cp /etc/odbcinst.ini  ~/infaagent/odbcinst.ini
```

Verify the agent-side `odbcinst.ini` really contains the `[PostgreSQL Unicode]` section:

```bash
cat ~/infaagent/odbcinst.ini
```

---

## Step 6 — Fix the SCRAM/OpenSSL segfault (critical)

you may face this issue, or you will not face at all.
**Symptom:** the connection _test_ may pass, but running a job crashes the DTM:

```
Internal error. The DTM process terminated unexpectedly.
```

The session log (`~/infaagent/apps/Data_Integration_Server/logs/tomcat/tomcat_*.log`) shows a `SIGSEGV` with this signature:

```
libpmcrypto.so.1.0.0(HMAC_Init_ex ...)
libpq.so.5(PQconnectPoll ...)
psqlodbcw.so(SQLConnect ...)
```

**Cause:** `libpq` performs SCRAM-SHA-256 password hashing through the system OpenSSL, but the agent has already loaded its **own** bundled OpenSSL 1.0.0 (`libpmcrypto`). The two conflict and crash the moment a password is hashed.

**Fix:** remove the password-crypto path for local connections by switching PostgreSQL to `trust` auth (acceptable for a local, non-exposed learning DB).

Edit `pg_hba.conf`:

```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

Change the **METHOD** column on the IPv4/IPv6 local lines to `trust`:

```
# TYPE  DATABASE  USER  ADDRESS         METHOD
host    all       all   127.0.0.1/32    trust
host    all       all   ::1/128         trust
```

Save (`Ctrl+O`, Enter, `Ctrl+X`), then reload:

```bash
sudo systemctl restart postgresql
```

Verify:

```bash
grep -E '^host\s+all' /etc/postgresql/*/main/pg_hba.conf
```

Because the DSN connects to **`127.0.0.1`** (Step 3), it matches this `trust` rule and sends no password — so the crashing crypto code is never reached.

> **Security note:** `trust` means no password is required from `127.0.0.1`. This is fine for a throwaway local learning DB bound to localhost on a single VM. **Never** use `trust` on a shared or internet-exposed database.
>
> **If it still segfaults** even with `trust`, also disable SSL in the DSN by adding `SSLmode = disable` (or `SSLMode = disable`) to the `[PostgresDSN]` sections in **both** `odbc.ini` files, then restart the agent.

---

## Step 7 — Fix missing system libraries (if the DTM won't launch)

**Symptom (in the tomcat session log):**

```
pmdtm: error while loading shared libraries: libidn.so.11: cannot open shared object file
```

The agent engine needs the old `libidn.so.11`, which new distros don't ship.

**Fix on Ubuntu (newer releases):**

```bash
# The old package name may not exist:
sudo apt install -y libidn11 2>/dev/null || sudo apt install -y libidn12

# Confirm what you have:
find / -name "libidn.so*" 2>/dev/null
```

If only `libidn.so.12` exists, create the `.11` name and refresh the linker cache:

```bash
sudo ln -sf /usr/lib/x86_64-linux-gnu/libidn.so.12 /usr/lib/x86_64-linux-gnu/libidn.so.11
sudo ldconfig
```

> This is a **compat-symlink** approach: `.11` and `.12` are ABI-compatible enough for the agent. If the DTM later reports a _different_ missing `.so`, apply the same pattern (find the current version, symlink the old name, `ldconfig`).

---

## Step 8 — Restart the agent so it picks up all changes

```bash
cd ~/infaagent/apps/agentcore
./infaagent.sh shutdown

# Wait until fully stopped:
ps -ef | grep -i infaagent | grep -v grep      # must be empty

# Start once:
./infaagent.sh startup
```

---

## Step 9 — Create the ODBC connection in IICS

1. **Administrator → Connections → New Connection.**
2. Set:
   - **Connection Type:** `ODBC`
   - **Runtime Environment:** your Secure Agent
   - **Data Source Name (DSN):** `PostgresDSN` (must match `[PostgresDSN]` exactly)
   - **User Name:** `postgres`
   - **Password:** `admin123`
   - **ODBC Subtype:** `PostgreSQL` (select this if the field is present)
3. Click **Test Connection** — should succeed.

---

## Step 10 — Run an end-to-end job

1. Create a simple **Mapping**: PostgreSQL source (`emp` table via `PostgresDSN`) → target (flat file or another table).
2. In the **Source**, confirm the **Fields** tab shows columns (if empty, re-select the object to import metadata — an empty field list causes `Failed to generate mapping xml ... "c" is null`).
3. Save and **Run**.
4. Check **Monitor** in IICS — the job should complete and report row counts.

---

## Troubleshooting Quick Reference

| Error                                                                      | Root cause                                       | Fix                                                                        |
| -------------------------------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------- |
| `IM002 Data source name not found` in `isql`                               | DSN/driver name mismatch or wrong file location  | Match `Driver = PostgreSQL Unicode` to `odbcinst.ini`; check `odbcinst -j` |
| `IM002` in IICS but `isql` works                                           | Agent reads a different `odbcinst.ini`           | Copy config to `~/infaagent/` (Step 5)                                     |
| `DTM process terminated unexpectedly` + `SIGSEGV` in `libpmcrypto`/`libpq` | OpenSSL/SCRAM conflict                           | Use `trust` auth + `127.0.0.1` (Step 6)                                    |
| `pmdtm: error while loading shared libraries: libidn.so.11`                | Missing old system lib                           | Symlink `.11`→`.12`, `ldconfig` (Step 7)                                   |
| `Failed to generate mapping xml ... "c" is null`                           | Source/target has no imported fields             | Re-select the object to refresh metadata (Step 10)                         |
| Job runs standalone but task fails                                         | Bad Session/Error Log Directory path in the task | Correct the path in the mapping task properties                            |

---

## How the Data Flows (for understanding)

- **Design & orchestration** live in Informatica Cloud (mappings, tasks, monitoring).
- **The agent does the work locally.** For a join, the agent pulls rows from both sources into its DTM engine and joins them **in the agent's memory on the VM** (agent-based mode). Your data does **not** go to Informatica's cloud — only run statistics do.
- **Pushdown Optimization (PDO)**, when enabled and supported, instead pushes generated SQL down to the database so the join runs **inside PostgreSQL**. Data never leaves the DB.
- **One agent, many connections.** A single agent connects to as many databases as it can reach over the network. Add more agents only for network isolation, high availability, or load — not "one per source."
