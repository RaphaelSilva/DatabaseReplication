# YouTube Video Script: Proxmox Database Replication with IaC

**Title:** Master Proxmox DB Replication: Part 1 - Infrastructure & Setup (Terraform + Ansible)

---

## [0:00] Introduction
**Visual:** Montage of Proxmox dashboard, Terminal code scrolling, and a "Database Replication" diagram.

**Narrator:**
"Welcome back! In today's video, we're going to interact with the Holy Grail of self-hosting: Database Replication on Proxmox using Infrastructure as Code. We'll build a robust PostgreSQL cluster using Terraform to provision our containers and Ansible to configure the replication automatically."

"We'll cover:
1. Setting up Terraform for Proxmox.
2. The critical importance of the `.gitignore` file.
3. Essential troubleshooting tricks for permissions and networking.
4. How to backup and share your Terraform state using PostgreSQL, AWS, or GCP.
5. And finally, mastering Ansible modularity to keep your code DRY."

---

## [1:30] Part 1: Infrastructure as Code with Terraform
**Visual:** Split screen showing VS Code on the left and Proxmox UI on the right.

**Narrator:**
"Let's start with the infrastructure. We are using the `bpg/proxmox` provider to create our LXC containers. Here is our `main.tf`."

**(Access `terraform/main.tf`)**
"Key components here:
- **Provider Configuration**: verifying the endpoint and API token.
- **Resources**: `proxmox_virtual_environment_container`. notice how we use `for_each` to create multiple containers (primary and replicas) dynamically from a variable."

**Visual:** Highlight the `for_each` loop and `user_account` section in the code.

"Note the `user_account` block. we are injecting SSH keys directly here. This is crucial for Ansible to connect later without passwords."

### The Importance of Gitignore
**Visual:** Zoom in on the `.gitignore` file.

**Narrator:**
"Before you commit anything to GitHub, stop! You must protect your secrets. A proper `.gitignore` file is your first line of defense.
We are ignoring:
- `*.tfvars`: Contains our actual API tokens and passwords.
- `.env`: Environment variables.
- `terraform.tfstate` and `*.backup`: These files contain clear-text sensitive data about your infrastructure."

"Never, ever commit these files. Use a `terraform.tfvars.example` file instead to show your team what variables are needed without leaking your keys."

---

## [4:00] Part 2: Troubleshooting Tricks
**Visual:** Terminal showing error messages and successful commands.

**Narrator:**
"Things don't always go smoothly. Here are three checks I always do when things break."

### 1. Check Proxmox User Permissions
**Visual:** Recording of navigating Proxmox UI to `Datacenter` -> `Permissions`.
1. **Users:** Create `terraform-prov`.
2. **API Tokens:** Generate a token (Uncheck 'Privilege Separation' for full impersonation).
3. **Permissions:** Add `User Permission` on path `/` -> Select Token -> Role `PVEVMAdmin` (or a custom role with `VM.Allocate`, `Datastore.AllocateSpace`, `Sys.Audit`).

"If Terraform gives you a 'Forbidden' error, verify these steps. The token needs `VM.Allocate`, `Datastore.AllocateSpace`, and `Sys.Audit` on the target storage and node to create containers."

### 2. Check the Network
"Can your nodes talk to each other? If replication fails, it's often the network.
- Check firewall rules in Proxmox (Datacenter > Firewall).
- Verify the `bind_address` in PostgreSQL config is set to `*` or your specific subnet, not just `localhost`."

### 3. Database Permissions
"For replication, the replica needs to log in to the primary. Check your `pg_hba.conf`. You need a line strictly allowing the replication user from the replica's IP address using `scram-sha-256` or `trust` (only for private secure networks)."

---

## [6:30] Part 3: Terraform State Management
**Visual:** Diagram showing a developer machine pushing state to a central database (Postgres/S3).

**Narrator:**
"By default, Terraform stores state locally in `terraform.tfstate`. If your laptop dies, your infrastructure knowledge is lost. If you work in a team, you'll overwrite each other's work."

"The solution: **Remote Backends**."

**Visual:** Show `backend.hcl` configuration.

"We can configure Terraform to store its state in:
- **PostgreSQL**: Great for homelabs or on-prem setups.
- **AWS S3**: Industry standard, often used with DynamoDB for locking.
- **GCP Cloud Storage**: Simple and effective."

"Here, we're using the `pg` backend. This allows anyone with access to the database to manage the infrastructure, and provides locking to prevent two people from applying changes at the same time."

---

## [8:30] Part 4: Ansible Modularity (DRY)
**Visual:** Ansible directory structure, opening `playbook.yml` then sub-files.

**Narrator:**
"Now that our containers are up, we configure them with Ansible. But we don't want a 500-line playbook that's impossible to read. We follow the DRY principle: **Don't Repeat Yourself**."

"We've split our logic into:
1. `install_postgres.yml`: Installs packages (shared by all nodes).
2. `configure_primary.yml`: Specifics for the leader.
3. `configure_replicas.yml`: Steps to clone the data."

**Visual:** Show `playbook.yml`.

"Our main `playbook.yml` simply imports these sub-playbooks based on host groups. This makes your automation maintainable, reusable, and clean."

---

## [10:00] Outro
**Visual:** Camera on narrator / "Subscribe" animation.

**Narrator:**
"And there you have it! A fully automated, replicated database setup on Proxmox using modern IaC practices. We've covered Terraform config, security, troubleshooting, state management, and Ansible modularity."

"You can find all the code in the description below. If this helped you, drop a like and subscribe for more DevOps content!"

"And stay tuned for Part 2, where we will dive deep into the **Verification Plan**: testing the replication, forcing failovers, and ensuring our data is truly safe."

"See you in the next one!"
