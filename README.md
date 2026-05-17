**aws-terraform-ec2-iac** — Infrastructure-as-Code pipeline that provisions a fully networked AWS EC2 Java build server using Terraform modules and Ansible configuration management.

---

## Project at a Glance

| | |
|---|---|
| **Tools Used** | Terraform, Ansible, AWS EC2, AWS VPC, AWS SSM Parameter Store |
| **Platform** | Amazon Web Services (us-east-1) |
| **Languages** | HCL (Terraform), YAML (Ansible) |
| **What It Does** | Provisions a VPC, public subnet, security group, and a bootstrapped EC2 instance pre-loaded with Java 11, Maven 3.9, Docker, and Git — ready to serve as a CI build node |

---

## The Problem This Project Solves

Manually standing up a Java build environment on a fresh EC2 instance is a multi-step, error-prone process: create a VPC, configure route tables, attach an internet gateway, open the correct security group ports, launch an instance, SSH in, install a compatible JDK, download and configure Maven, install Docker, and wire up the correct environment variables. Doing this by hand takes 30-60 minutes, produces an undocumented snowflake server, and cannot be reliably reproduced across environments or team members.

This project encodes the entire provisioning workflow as version-controlled infrastructure. Terraform handles the AWS resource graph — VPC, subnets, routing, security groups, and the EC2 instance itself — while Ansible handles the software configuration layer: installing Java 11 via amazon-linux-extras, downloading and extracting Apache Maven 3.9.12 from the official mirror, creating the Docker group, and writing the correct environment variable exports into `/etc/profile.d/maven.sh`. The result is a repeatable, auditable build node that any team member can spin up with a single command.

For hiring managers and engineering leads: this project demonstrates practical knowledge of the Terraform module pattern (separating network concerns from compute concerns), the use of AWS SSM Parameter Store to dynamically resolve the latest Amazon Linux 2 AMI without hardcoding AMI IDs, and the use of Terraform provisioners to bridge the gap between infrastructure provisioning and application configuration management.

---

## Architecture

```
Local Machine
     |
     | terraform apply
     v
+-----------------------------+
|  ROOT MODULE (main.tf)      |
|  - Provider: AWS us-east-1  |
+----+----------------+-------+
     |                |
     v                v
+----------+   +--------------+
| modules/ |   | modules/     |
|   vpc    |   |   compute    |
+----------+   +--------------+
     |                |
     v                v
AWS VPC              EC2 Instance (t3.micro)
10.0.0.0/16          Amazon Linux 2
     |                |
     +--> Subnet       +--> Terraform file provisioner
          10.0.1.0/24       copies install_java_build.yaml
     |                |
     +--> IGW          +--> Terraform remote-exec provisioner
     |                      1. yum update
     +--> Route Table        2. amazon-linux-extras install ansible2
     |                      3. amazon-linux-extras install java-openjdk11
     +--> Security Group     4. ansible-playbook install_java_build.yaml
          TCP 22, 80,             - git, tree
          8080, 1233              - Docker + docker group
                                  - Apache Maven 3.9.12
                                  - M2_HOME env vars
```

---

## Repository Structure

```
aws-terraform-ec2-iac/
├── main.tf                      # Root module: wires vpc and compute modules together
├── variables.tf                 # Root-level variables (AWS region)
├── outputs.tf                   # Outputs: public IP of the Jenkins/build node
├── install_java_build.yaml      # Ansible playbook: Java, Maven, Docker configuration
├── modules/
│   ├── vpc/
│   │   ├── main.tf              # VPC, IGW, public subnet, route table, security group
│   │   ├── variables.tf         # Region variable
│   │   └── outputs.tf           # Exports: subnet ID, security group ID, subnet CIDR
│   └── compute/
│       ├── main.tf              # EC2 instance, key pair, SSM AMI lookup, provisioners
│       ├── variables.tf         # Region, SSH key paths, subnet, security group inputs
│       └── outputs.tf           # Exports: instance ID, public IP, private IP
└── .gitignore
```

---

## How It Works

The root `main.tf` instantiates two child modules in dependency order. The `vpc` module runs first, creating a `/16` VPC in `us-east-1`, a public subnet in the first available availability zone, an internet gateway, a public route table, and a security group that permits inbound TCP on ports 22 (SSH), 80 (HTTP), 8080 (Jenkins/app), and 1233 (custom). The module exports the subnet ID, security group ID, and subnet CIDR as outputs.

The `compute` module receives those outputs as inputs. It queries AWS SSM Parameter Store for the current Amazon Linux 2 AMI ID — avoiding hardcoded AMI references — and creates a `t3.micro` EC2 instance with a registered SSH key pair. Once the instance is reachable, two Terraform provisioners fire sequentially: a `file` provisioner copies `install_java_build.yaml` from the local filesystem to the remote instance, then a `remote-exec` provisioner runs `yum update`, installs Ansible 2 and Java 11 via `amazon-linux-extras`, and finally executes the Ansible playbook locally on the instance.

The Ansible playbook (`install_java_build.yaml`) uses structured blocks to install Docker (and add `ec2-user` to the docker group), download and extract Apache Maven 3.9.12 from the official Apache mirror into `/opt`, create a symlink at `/usr/bin/mvn`, and write `M2_HOME` and updated `PATH` entries into `/etc/profile.d/maven.sh` for persistent environment configuration.

---

## Walkthrough

**1. Initialize the Terraform working directory**
```bash
terraform init
```

**2. Preview the planned changes**
```bash
terraform plan
```

**3. Apply the configuration**
```bash
terraform apply
```
Terraform will provision the VPC stack, launch the EC2 instance, copy the Ansible playbook via SCP, and execute it remotely. Total provisioning time is approximately 3-5 minutes.

**4. Retrieve the build server's public IP**
```bash
terraform output Jenkins-Node-Public-IP
```

**5. SSH into the instance to verify tools**
```bash
ssh -i ~/.ssh/id_ed25519 ec2-user@<public-ip>
java -version       # openjdk 11
mvn -version        # Apache Maven 3.9.12
docker --version    # Docker
```

**6. Destroy all resources when done**
```bash
terraform destroy
```

---

## How to Reproduce

**Prerequisites**
- Terraform >= 0.15.5
- An AWS account with credentials configured (`~/.aws/credentials` or environment variables)
- An SSH key pair at `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`

**Steps**
```bash
# Clone the repository
git clone https://github.com/<your-username>/aws-terraform-ec2-iac.git
cd aws-terraform-ec2-iac

# If your SSH keys are in a different location, edit modules/compute/variables.tf:
# ssh_key_public  = "~/.ssh/your-key.pub"
# ssh_key_private = "~/.ssh/your-key"

# Initialize and apply
terraform init
terraform apply -auto-approve

# Get the public IP
terraform output Jenkins-Node-Public-IP

# Clean up
terraform destroy -auto-approve
```

The default region is `us-east-1`. To deploy in a different region, override the variable:
```bash
terraform apply -var="region=us-west-2"
```

---

*Oluwaseyi Michael Falode · Cybersecurity & Cloud Security Engineer · Toronto, ON*
