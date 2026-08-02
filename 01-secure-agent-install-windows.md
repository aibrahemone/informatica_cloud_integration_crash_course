# Installing the Informatica Cloud Secure Agent on Windows

This guide walks through installing the Informatica Intelligent Cloud Services (IICS / IDMC) Secure Agent on a **Windows 64-bit** machine.

> **What is the Secure Agent?**
> The Secure Agent is a lightweight program that runs in your environment and does the actual data movement. Informatica Cloud holds the _design and orchestration_ (mappings, tasks, monitoring); the agent is the _worker_ that connects to your databases, processes the data locally, and reports run statistics back to the cloud over port 443. Your actual row data never leaves your environment.

---

## 1. Prerequisites

| Requirement | Detail                                                               |
| ----------- | -------------------------------------------------------------------- |
| OS          | Windows 64-bit (Windows Server 2016+ or Windows 10/11 64-bit)        |
| RAM         | 8 GB minimum recommended (the agent runs several Java microservices) |
| Disk        | ~5 GB free for the agent plus working space                          |
| CPU         | x86-64 architecture                                                  |
| Network     | Outbound HTTPS (port **443**) to Informatica Cloud must be allowed   |
| Account     | A valid IICS / IDMC login (free trial or licensed)                   |
| Privileges  | A Windows user with local administrator rights                       |

> **Note on the install user:** Use a dedicated user whose name is short (avoid names longer than ~14 characters and avoid spaces). The agent runs as a Windows service under this account.

---

## 2. Download the Secure Agent

1. Log in to **Informatica Intelligent Cloud Services** at <https://dm-us.informaticacloud.com> (or your regional POD).
2. From the **My Services** page, open **Administrator**.
3. In the left menu, click **Runtime Environments**.
4. Click **Download Secure Agent** (or **New Runtime Environment → Download Secure Agent**).
5. In the dialog:
   - **Platform:** select **Windows 64**.
   - **Install Token:** click **Copy** and save the token somewhere safe — you need it to register the agent. (Tokens are time-limited; generate a fresh one if it expires.)
6. Click **Download**. This saves `agent64_install.exe`.

---

## 3. Run the Installer

1. Copy `agent64_install.exe` to the machine where the agent will run.
2. Right-click the installer and choose **Run as administrator**.
3. Choose the install folder (default is `C:\Program Files\Informatica Cloud Secure Agent`) and continue.
4. The installer sets up the agent as a **Windows service** and starts it automatically.

---

## 4. Register the Agent

After installation, the **Secure Agent Manager** window opens (or launch it from the Start menu).

1. Enter the **User Name** — the email/username of your IICS account.
2. Enter the **Install Token** you copied earlier.
3. Click **Register**.

The agent connects to Informatica Cloud and begins downloading and starting its microservices (Data Integration Server, etc.). This takes a few minutes on first run.

---

## 5. Verify the Agent Is Running

**In the Secure Agent Manager:** the status should read **Running / Up and Running** with all services green.

**In IICS:** go to **Administrator → Runtime Environments**. Your agent should appear with a green **Up and Running** status.

**As a Windows service:** open `services.msc` and confirm **Informatica Cloud Secure Agent** is _Running_ and set to _Automatic_ start.

---

## 6. Common Issues

| Symptom                               | Cause / Fix                                                                                                                                                        |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Agent shows offline in IICS           | Outbound port 443 blocked by firewall/proxy. Allow HTTPS to the Informatica POD. Configure proxy in the Secure Agent Manager if needed.                            |
| Services keep restarting              | Insufficient RAM. Give the machine at least 8 GB.                                                                                                                  |
| "DTM process terminated unexpectedly" | Often a resource shortage (RAM/disk) or a Windows performance-counter issue. Free resources; if performance counters are corrupted, rebuild them with `lodctr /r`. |
| Register fails / token invalid        | Token expired. Generate a new install token in IICS and re-register.                                                                                               |

---

## 7. Managing the Agent

- **Stop/Start:** use the Secure Agent Manager, or `services.msc`.
- **Uninstall:** stop the service, then use _Add/Remove Programs_.
- **One agent, many connections:** a single agent can serve many database connections. You do **not** need one agent per data source — scale to multiple agents only for network reach, high availability, or load balancing.

---

## References

- Informatica Documentation: <https://docs.informatica.com>
- Secure Agent (Runtime Environments) admin guide in IICS Administrator help.
