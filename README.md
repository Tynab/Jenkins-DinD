# Jenkins Docker-in-Docker

Image Jenkins LTS có sẵn Docker CLI, Buildx và Compose V2 để pipeline build/push container thông qua một Docker-in-Docker (DinD) sidecar riêng biệt.

## Tổng quan kỹ thuật

Repository dùng kiến trúc hai container:

- `jenkins`: Jenkins `2.555.3-jdk21`, chạy bằng user `jenkins`, chỉ chứa công cụ dòng lệnh Docker.
- `docker`: Docker Engine `29-dind`, chạy đặc quyền để cung cấp daemon.
- Hai container giao tiếp nội bộ tại `tcp://docker:2376` bằng chứng thư TLS tự sinh.
- Volume `jenkins-data` lưu cấu hình/workspace; `docker-certs-client` chia sẻ chứng thư client ở chế độ chỉ đọc cho Jenkins.

Thiết kế này tách daemon đặc quyền khỏi Jenkins, thay thế cách cũ cài Docker Engine nhưng không khởi động được daemon trong cùng image.

## Thành phần

| Tệp | Vai trò |
| --- | --- |
| `Dockerfile` | Build Jenkins LTS với Docker CLI, Buildx, Compose V2 và healthcheck. |
| `compose.yaml` | Khởi tạo Jenkins, DinD sidecar, TLS, network và persistent volumes. |
| `.dockerignore` | Thu nhỏ build context và loại metadata không cần thiết. |
| `.gitattributes` | Chuẩn hóa line ending LF trên mọi hệ điều hành. |
| `.github/FUNDING.yml` | Khai báo các kênh tài trợ hiển thị trên GitHub. |

## Yêu cầu

- Docker Engine hoặc Docker Desktop có hỗ trợ Linux containers.
- Docker Compose V2 (`docker compose`).
- Tối thiểu 4 GB RAM khả dụng cho Docker.
- Cổng `8080` và `50000` chưa được dịch vụ khác sử dụng.

> DinD cần `privileged: true`. Chỉ chạy stack trên máy/runner tin cậy và không công khai cổng Docker TLS `2376` ra host.

## Khởi động nhanh

Build image và chạy toàn bộ stack:

```bash
docker compose up -d --build
```

Nếu cổng mặc định đã được sử dụng, có thể đổi cổng host mà không sửa file:

```bash
JENKINS_HTTP_PORT=18080 JENKINS_AGENT_PORT=50001 docker compose up -d --build
```

Theo dõi trạng thái:

```bash
docker compose ps
docker compose logs -f jenkins
```

Lấy mật khẩu quản trị ban đầu:

```bash
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Mở `http://localhost:8080`, nhập mật khẩu trên và hoàn tất trình hướng dẫn Jenkins.

## Xác minh Docker trong Jenkins

Kiểm tra kết nối TLS tới DinD sidecar:

```bash
docker compose exec jenkins docker version
docker compose exec jenkins docker info
docker compose exec jenkins docker buildx version
docker compose exec jenkins docker compose version
```

Trong Jenkins Pipeline, một stage tối thiểu có thể dùng:

```groovy
pipeline {
    agent any
    stages {
        stage('Kiểm tra Docker') {
            steps {
                sh 'docker version'
            }
        }
    }
}
```

## Build và phát hành image

Build image cục bộ:

```bash
docker build --pull -t yamiannephilim/jenkins:latest .
```

Đăng nhập và push lên Docker Hub:

```bash
docker login
docker push yamiannephilim/jenkins:latest
```

Image công khai: [yamiannephilim/jenkins](https://hub.docker.com/r/yamiannephilim/jenkins)

## Vận hành

Dừng stack nhưng giữ dữ liệu:

```bash
docker compose down
```

Xóa cả dữ liệu Jenkins và chứng thư TLS:

```bash
docker compose down --volumes
```

Đổi phiên bản Jenkins bằng build argument:

```bash
docker build --build-arg JENKINS_VERSION=2.555.3-jdk21 -t yamiannephilim/jenkins:latest .
```

Khi nâng phiên bản, cập nhật đồng thời `Dockerfile`, `compose.yaml` và nội dung kỹ thuật trong README để tránh sai lệch.

## Tóm tắt

Repository cung cấp môi trường Jenkins có khả năng chạy lệnh Docker theo mô hình DinD sidecar chính thức: daemon được cô lập, kết nối được mã hóa TLS, dữ liệu được lưu bền vững và image Jenkins vẫn chạy bằng user không đặc quyền.
