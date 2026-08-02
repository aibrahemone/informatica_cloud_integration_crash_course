# Installing the Informatica Cloud Secure Agent on Linux

This guide walks through installing the IICS / IDMC Secure Agent on any **Linux 64-bit** host — a physical server, an on-prem VM, or a cloud instance (AWS, Azure, GCP, etc.). All commands are standard Linux and are not tied to any specific provider.

---

## 1. Provision the Host

| Requirement  | Recommended                                                                            |
| ------------ | -------------------------------------------------------------------------------------- |
| OS           | 64-bit Linux (RHEL/Rocky/Alma or Ubuntu/Debian). **See the OS-version warning below.** |
| Architecture | **x86-64** (do _not_ use ARM — the agent is x86-64 only)                               |
| CPU          | 2+ cores                                                                               |
| RAM          | **8 GB minimum**; 16 GB for comfort when running a local database alongside            |
| Disk         | 20–30 GB free                                                                          |
| Network      | Outbound HTTPS (port **443**) allowed. No inbound ports required for the agent.        |

Verify your host meets the basics:

```bash
uname -m          # must be x86_64
nproc             # CPU cores
free -m           # RAM in MB
df -h /           # free disk on the root filesystem
cat /etc/os-release   # distro and version
```

> ### ⚠️ OS-version warning (important)
>
> The agent's native engine (`pmdtm`) is built against **older system libraries**. On very new distros (e.g. the latest Ubuntu releases) you will hit missing-library errors such as `libidn.so.11: cannot open shared object file`. A stable LTS like **Ubuntu 22.04** or **RHEL/Rocky 8/9** avoids most of these. If you must use a newer distro, see the library fixes in `03-odbc-postgresql-setup.md`.

---

## 2. Connect to the Host

Connect to your Linux host over SSH as the user that will own the agent (avoid installing as `root`):

```bash
ssh <user>@<host-ip-or-name>
```

Use whatever access method your environment provides (SSH key, jump host, or a cloud provider's browser/console SSH). The rest of this guide runs inside that shell.

---

## 3. Download the Secure Agent from IICS

1. Log in to **Informatica Intelligent Cloud Services**.
2. Open **Administrator → Runtime Environments**.
3. Click **New Runtime Environment** (or **Download Secure Agent**).
4. Choose **Download Secure Agent**.
5. In the dialog:
   - **Platform:** select **Linux 64**.
   - **Install Token:** click **Copy** and save it — you need it to register.
6. Click **Download** to get the installer, `agent64_install_ng_ext.bin`.

**Transfer the `.bin` to the host (if you downloaded it locally):**

```bash
# From your local machine, copy it over SSH:
scp ~/Downloads/agent64_install_ng_ext.bin <user>@<host>:~/
```

Any file-transfer method works (`scp`, `rsync`, SFTP, or a console upload feature if your platform provides one).

---

## 4. Run the Installer (Console Mode)

A headless server has no display, so the installer automatically uses **console mode** (graphical mode is not supported without a desktop environment).

```bash
chmod +x agent64_install_ng_ext.bin
./agent64_install_ng_ext.bin
```

The installer will:

1. Extract and unpack a bundled JRE.
2. Detect the headless environment and print: _"Graphical installers are not supported... The console mode should be used instead..."_
3. Prompt **Choose Install Folder** — press **Enter** to accept the default:
   ```
   Default Install Folder: /home/<user>/infaagent
   ```
4. Show a **Pre-Installation Summary** (product name, install folder, disk space). Press **Enter** to continue.
5. Install the files.

---

## 5. Register the Agent with a Token

Move into the agent core directory and register using your org login and install token:

```bash
cd ~/infaagent/apps/agentcore

# Register the agent (v3 token login):
./consoleAgentManager.sh configureToken <YOUR_USERNAME> <INSTALL_TOKEN>
```

You should see:

```
Login with token
Login succeeded.
```

Confirm the agent is configured:

```bash
./consoleAgentManager.sh isConfigured
# -> true
```

---

## 6. Start the Agent

```bash
cd ~/infaagent/apps/agentcore
./infaagent.sh startup
```

> **⚠️ Start it only ONCE.** Running `startup` more than once spawns duplicate agent cores that fight over a lock file, producing a crash loop with:
> `ERROR ... Cannot acquire lock, there is probably another instance running.`
> If that happens: `pkill -9 -f infaagent`, wait until `ps -ef | grep -i infaagent | grep -v grep` is empty, remove any stale `*.lock`, then start **once**.

---

## 7. Verify the Agent Is Running

**Check the processes** — you should see a single agent core plus microservices coming up:

```bash
ps -ef | grep -i infaagent | grep -v grep
```

Expected services (each is a Java process): `agentcore` (MainApp), `Administrator`, `OpsInsightsDataCollector`, `Common_Integration_Components`, `MassIngestionRuntime`, and **`Data_Integration_Server`** (the one that runs mappings).

**Watch it settle:**

```bash
tail -f ~/infaagent/apps/agentcore/agentcore.log
```

**In IICS:** Administrator → Runtime Environments → your agent shows green **Up and Running**.

---

## 8. Managing the Agent

```bash
cd ~/infaagent/apps/agentcore

# Stop (graceful):
./infaagent.sh shutdown

# Confirm fully stopped before restarting:
ps -ef | grep -i infaagent | grep -v grep     # must be empty

# Start (once):
./infaagent.sh startup
```

**Memory note:** the microservices together can request 7+ GB of Java heap (OpsInsights alone up to 3 GB). On a host with only 4 GB and no swap, they will be killed by the OOM killer under load. Use **8 GB+**, or add swap:

```bash
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
```

---

## 9. Common Issues

| Symptom                                                     | Cause / Fix                                                            |
| ----------------------------------------------------------- | ---------------------------------------------------------------------- |
| `Cannot acquire lock ... Only one instance can be running`  | Duplicate `startup`. Kill all, clear locks, start once (see §6).       |
| `Agent core exited with 2` in a loop                        | Usually the lock issue above, or low RAM. Check `free -m` and the log. |
| Services die randomly under load                            | Out of memory. Increase RAM to 8 GB+ or add swap.                      |
| Agent not "Up and Running" in IICS                          | Outbound 443 blocked, or registration incomplete.                      |
| `pmdtm: error while loading shared libraries: libidn.so.11` | Newer distro missing an old lib. See `03-odbc-postgresql-setup.md`.    |

---

## Next Step

Once the agent is **Up and Running**, set up your database connectivity. For PostgreSQL via ODBC, follow **`03-odbc-postgresql-setup.md`** — it includes the critical library and authentication fixes needed on modern Linux.
