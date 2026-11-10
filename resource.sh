
#!/bin/bash

set -euxo pipefail

exec > >(tee /var/log/zomato-bootstrap.log | logger -t zomato-bootstrap -s 2>/dev/console) 2>&1

# Update packages
apt-get update -y

# Install required dependencies and Java 21
apt-get install -y \
  ca-certificates \
  curl \
  wget \
  gnupg \
  unzip \
  jq \
  fontconfig \
  openjdk-21-jre-headless

java -version

# -------------------------------
# Install Jenkins
# -------------------------------

mkdir -p /etc/apt/keyrings

wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update -y
apt-get install -y jenkins

systemctl enable --now jenkins

# -------------------------------
# Install Docker
# -------------------------------

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release

DOCKER_CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${DOCKER_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y

apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable --now docker

# Jenkins needs Docker access for Docker build stages.
# Docker group membership provides root-equivalent privileges.
usermod -aG docker jenkins

# -------------------------------
# SonarQube kernel requirements
# -------------------------------

cat > /etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl --system

# -------------------------------
# Install SonarQube using Docker
# -------------------------------

docker pull sonarqube:lts-community

docker run -d \
  --name zomato-sonarqube \
  --restart unless-stopped \
  --memory=3g \
  --ulimit nofile=131072:131072 \
  --ulimit nproc=8192:8192 \
  -p 9000:9000 \
  sonarqube:lts-community

# -------------------------------
# Install Trivy
# -------------------------------

apt-get install -y wget gnupg lsb-release

wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor -o /usr/share/keyrings/trivy.gpg

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  > /etc/apt/sources.list.d/trivy.list

apt-get update -y
apt-get install -y trivy

# -------------------------------
# Install AWS CLI v2
# -------------------------------

curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
  -o /tmp/awscliv2.zip

unzip -q /tmp/awscliv2.zip -d /tmp

/tmp/aws/install

rm -rf /tmp/aws /tmp/awscliv2.zip

# -------------------------------
# Install kubectl
# -------------------------------

KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

curl -fsSLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

curl -fsSLo /tmp/kubectl.sha256 \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" \
  | sha256sum -c -

chmod +x /usr/local/bin/kubectl

# -------------------------------
# Install eksctl
# -------------------------------

curl -fsSL \
  https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz \
  -o /tmp/eksctl.tar.gz

tar -xzf /tmp/eksctl.tar.gz -C /tmp

install -m 0755 /tmp/eksctl /usr/local/bin/eksctl

rm -f /tmp/eksctl /tmp/eksctl.tar.gz

# Restart Jenkins to apply Docker group membership
systemctl restart jenkins

# -------------------------------
# Verify installations
# -------------------------------

echo "========== ZOMATO DEVSECOPS TOOLS =========="

java -version
docker --version
docker compose version
jenkins --version || true
trivy --version
aws --version
kubectl version --client
eksctl version

echo "Zomato DevSecOps bootstrap completed."
