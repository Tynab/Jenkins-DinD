# Jenkins LTS 2.555.3 chạy trên JDK 21; ghim image nền để hạn chế thay đổi ngoài ý muốn.
ARG JENKINS_VERSION=2.555.3-jdk21
FROM jenkins/jenkins:${JENKINS_VERSION}

ARG JENKINS_VERSION
LABEL org.opencontainers.image.title="Jenkins with Docker CLI" \
      org.opencontainers.image.description="Jenkins LTS kết nối an toàn tới Docker-in-Docker sidecar qua TLS." \
      org.opencontainers.image.source="https://github.com/Tynab/Jenkins-DinD" \
      org.opencontainers.image.version="${JENKINS_VERSION}"

USER root

# Cài Docker CLI từ kho chính thức bằng keyring hiện đại; không cài daemon vào container Jenkins.
# Buildx và Compose V2 hỗ trợ đầy đủ các pipeline build image nhiều kiến trúc và stack Compose.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"${VERSION_CODENAME}\") stable" \
        > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Jenkins phải chạy bằng tài khoản không đặc quyền của image gốc.
USER jenkins

# Endpoint đăng nhập phản ánh cả trạng thái HTTP và mức sẵn sàng của Jenkins.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=5 \
    CMD curl -fsS http://localhost:8080/login > /dev/null || exit 1

# Tóm tắt: image cung cấp Jenkins LTS cùng Docker CLI/Buildx/Compose; daemon nằm ở sidecar.
