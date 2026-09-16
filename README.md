# Ansible Professional Lab

A hands-on DevOps automation project using **Ansible, Jenkins, Docker, GitHub, and Google Cloud**.

The project demonstrates a complete automation path where a GitHub push triggers Jenkins, Jenkins validates and runs Ansible, Ansible connects to a remote Ubuntu VM over SSH, deploys a Dockerized web application, and verifies that the correct application is healthy.

## Architecture

```text
Developer
   |
   | git push
   v
GitHub
   |
   | webhook
   v
Jenkins
   |
   | Jenkinsfile
   | credentials injection
   v
deploy.sh
   |
   v
Ansible
   |
   | SSH
   v
Ubuntu DevOps VM
   |
   +-- common role
   +-- docker role
   +-- webapp role
   |
   v
Docker / Nginx
   |
   v
Application health verification
```

## Technologies

| Area | Technology |
|---|---|
| Configuration Management | Ansible |
| CI/CD | Jenkins |
| Source Control | Git / GitHub |
| Cloud | Google Cloud Platform |
| OS | Ubuntu 22.04 LTS |
| Containers | Docker |
| Web Server | Nginx |
| Secrets | Ansible Vault + Jenkins Credentials |
| Templates | Jinja2 |
| Remote Access | SSH |
| Pipeline as Code | Jenkinsfile |
| Triggering | GitHub Webhook |

## Repository Structure

```text
ansible-professional-lab/
├── ansible.cfg
├── site.yml
├── Jenkinsfile
├── .gitignore
├── inventory/
│   └── hosts.yml
├── group_vars/
│   ├── dev.yml
│   └── all/
│       ├── main.yml
│       └── vault.yml
├── host_vars/
│   ├── local-dev.yml
│   └── ubuntu-devops.yml
├── roles/
│   ├── common/
│   ├── docker/
│   └── webapp/
└── scripts/
    └── deploy.sh
```

## Ansible Concepts Demonstrated

- inventories
- `group_vars`
- `host_vars`
- facts
- conditionals
- loops
- roles
- handlers
- Jinja2 templates
- tags
- Ansible Vault
- check mode
- syntax validation
- SSH remote automation
- privilege escalation with `become`
- idempotency
- application-aware health checks

## Variables

Shared variables are stored in:

```text
group_vars/all/main.yml
```

Development variables are stored in:

```text
group_vars/dev.yml
```

Host-specific variables are stored under:

```text
host_vars/
```

This allows the same playbook to behave differently depending on the target host or environment.

## Ansible Vault

Secrets are kept in:

```text
group_vars/all/vault.yml
```

The Vault file is encrypted and can be committed safely, while the actual Vault password stays outside the repository.

Jenkins stores the Vault password using **Jenkins Credentials** and exposes it only during the deployment stage.

## Common Role

The `common` role manages baseline host configuration and demonstrates:

- package management
- facts
- variables
- templates
- handlers
- environment-specific behavior

## Docker Role

The Docker role does not blindly reinstall Docker.

It first checks the existing installation, validates the Docker version, ensures the Docker service is running, and manages user group membership.

This avoids package conflicts between Docker CE, `docker.io`, `containerd`, and `containerd.io`.

## Web Application Role

The `webapp` role:

- creates the application directory
- renders the Nginx page with Jinja2
- checks whether the container exists
- starts or restarts the container when required
- waits for the service port
- verifies HTTP status
- verifies a unique application marker

The application runs on:

```text
Host port: 8081
Container port: 80
```

## Strong Health Checks

A major lesson from the project:

```text
HTTP 200 does not automatically mean the correct application is healthy.
```

An older service was already responding on port 8080. The final health check therefore validates both HTTP status and the marker:

```text
LAWAL-ANSIBLE-WEBAPP
```

## Handlers and Controlled Restart

When the application template changes:

```text
Template change
   ↓
Handler notification
   ↓
Container restart
   ↓
Port wait
   ↓
Application verification
```

The playbook flushes handlers before the final health check.

## Idempotency

Repeated runs do not make unnecessary changes.

A clean run looks like:

```text
ok=8
changed=0
unreachable=0
failed=0
```

## Deployment Script

The deployment entry point is:

```bash
./scripts/deploy.sh
```

It supports both local Cloud Shell use and Jenkins automation.

The script handles:

- target host selection
- Ansible tags
- Vault password file
- SSH private key
- optional host override
- playbook execution

## Jenkins

Jenkins runs in Docker with persistent storage using:

```text
jenkins_home
```

A custom Jenkins image was built with:

- Git
- Python
- Ansible
- OpenSSH client
- rsync

This allows Jenkins to run Ansible directly.

## Jenkins Credentials

Jenkins securely stores:

```text
ansible-ssh-key
ansible-vault-password
```

Neither secret is stored in GitHub.

During deployment Jenkins injects credentials temporarily, runs the playbook, and removes the temporary Vault password file afterward.

## Jenkins Pipeline

The `Jenkinsfile` performs:

```text
Checkout
   ↓
Validate
   ↓
Deploy
   ↓
Verify
```

### Checkout

Jenkins retrieves the project from GitHub.

### Validate

The pipeline runs:

```bash
ansible --version
ansible-playbook site.yml --syntax-check
```

### Deploy

Jenkins injects SSH and Vault credentials and executes:

```bash
./scripts/deploy.sh
```

### Verify

The final stage checks the deployed application and confirms the response contains:

```text
LAWAL-ANSIBLE-WEBAPP
```

A successful pipeline ends with:

```text
Application verification successful.
Finished: SUCCESS
```

## GitHub Webhook

GitHub automatically triggers Jenkins after a push:

```text
git push
   ↓
GitHub
   ↓
Webhook
   ↓
Jenkins
```

This removes the need to manually click **Build Now**.

## Troubleshooting Performed

### Cloud Shell Docker Package Conflict

Installing Ubuntu's `docker.io` conflicted with an existing `containerd.io` installation.

**Lesson:** inspect existing package state before changing it.

### Full Root Filesystem

The remote VM reached 100% disk usage, preventing Python and Ansible from creating temporary files.

Diagnosis included:

```bash
df -h
df -i
du
docker system df
journalctl --disk-usage
```

The boot disk was expanded to provide enough space for Jenkins and container workloads.

### Stale APT Process

A long-running `apt-get update` process held the APT lock.

**Lesson:** identify the process holding a package-manager lock rather than deleting lock files blindly.

### Docker Port Collision

The first webapp deployment tried to use port 8080, which was already occupied.

The Ansible-managed application was moved to port 8081 without disrupting the older workload.

### False-Positive Health Check

The older application returned HTTP 200, so a simple status check appeared successful even though the new container had failed.

The final health check validates the actual application identity.

### Jenkins Initially Had No Ansible

The standard Jenkins Docker image contained Git but not Ansible.

A custom Jenkins image was built with Python, Ansible, SSH tools, and rsync.

### Jenkins SCM Branch Issue

Jenkins initially reported:

```text
Couldn't find any revision to build
```

The job was corrected to use the `main` branch.

## Security Practices

- SSH private key is not committed to Git
- Vault password is not committed to Git
- secrets are stored in Ansible Vault or Jenkins Credentials
- Jenkins masks credentials in pipeline logs
- temporary Vault password files are deleted after use
- Jenkins workspace is cleaned after builds
- deployment uses SSH
- application verification checks the expected application identity

## Successful End-to-End Flow

```text
GitHub Push              ✅
GitHub Webhook           ✅
Jenkins Pipeline         ✅
Ansible Validation       ✅
Jenkins Credentials      ✅
Remote SSH Deployment    ✅
Docker Web Application   ✅
Health Verification      ✅
Idempotent Deployment    ✅
```

## Key DevOps Lessons

1. Inspect before changing.
2. Prefer desired-state automation over blind shell commands.
3. Keep secrets out of Git.
4. Validate before deployment.
5. Health checks should verify the correct application.
6. Jenkins orchestrates the workflow; Ansible manages remote system state.
7. Automate repeatable deployment steps.
8. Idempotency matters in production automation.

## Current Status

**Core Jenkins + Ansible CI/CD automation completed successfully.**

## Future Improvements

- Jenkins build parameters
- branch-aware deployments
- staging and production inventories
- manual approval gates
- notifications
- dynamic cloud inventory
- Molecule testing
- HTTPS for Jenkins
- reverse proxy
- monitoring and observability
- cloud secret-manager integration

## Author

**Lawal Oladele Sulaiman**

DevOps / Cloud Engineering Portfolio Project
