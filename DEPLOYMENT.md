# Hướng dẫn Deploy Tự Động (9Router & DeepSeek Harness)

Tài liệu này hướng dẫn cách đóng gói và triển khai nhanh ứng dụng **9Router** và **DeepSeek Harness** trên máy chủ Linux/VPS sử dụng PM2 và Nginx Reverse Proxy.

---

## 🚀 Cách triển khai nhanh (Quick Start)

### 1. Triển khai với tên miền mặc định (`router.sontv.test` và `dsh.sontv.test`)

Chạy lệnh sau tại thư mục gốc của dự án:
```bash
./deploy.sh
```

---

### 2. Triển khai Lựa chọn Agent Cụ thể (Select specific Agent)

Nếu bạn chỉ muốn chọn triển khai một Agent riêng lẻ (ví dụ chỉ 9Router hoặc chỉ DeepSeek Harness):

```bash
# Chỉ deploy 9Router:
./deploy.sh --only 9router

# Chỉ deploy DeepSeek Harness:
./deploy.sh --only dsh

# Triển khai cả hai (Mặc định):
./deploy.sh --only all
```

---

### 3. Triển khai với Tên miền (Host) Tùy chỉnh

Bạn có thể kết hợp lựa chọn Agent và truyền tên miền tùy chỉnh:

#### Cách 1: Sử dụng tham số dòng lệnh (CLI flags)
```bash
./deploy.sh --only 9router --router-domain 9router.sontv.io.vn --initial-password "MatKhauBaoMatCuaBan123!"
```

#### Cách 2: Sử dụng Biến môi trường (Environment variables)
```bash
INITIAL_PASSWORD="MatKhauBaoMatCuaBan123!" ROUTER_DOMAIN="9router.sontv.io.vn" ./deploy.sh
```

---

## 🛠️ Quy trình Script Tự Động Thực Hiện

Khi chạy `./deploy.sh`, kịch bản sẽ tự động thực hiện các bước:
1. **Kiểm tra môi trường**: Kiểm tra và tự tạo đường dẫn cho `Node.js`, `pnpm`, `pm2`, `nginx`.
2. **Cài đặt & Build**: Cài đặt dependencies (`pnpm install`) và build giao diện Next.js cho 9router và DSH.
3. **Cấu hình Nginx**: 
   - Tự động sinh file cấu hình Virtual Host trong `/etc/nginx/sites-available/` cho 2 tên miền đã chọn.
   - Bật hỗ trợ WebSockets và HTTP Streaming cho các phản hồi LLM.
   - Tạo file xác thực Nginx Basic Auth (`/etc/nginx/.htpasswd`) mặc định `admin`/`admin`.
   - Kiểm tra cú pháp (`nginx -t`) và reload Nginx service.
4. **Khởi chạy PM2**:
   - Khởi chạy các dịch vụ theo file `config/ecosystem.config.js`.
   - Lưu trạng thái với `pm2 save`.

---

## 📋 Quản lý dịch vụ với PM2

- **Xem trạng thái**:
  ```bash
  pm2 status
  ```
- **Xem logs real-time**:
  ```bash
  pm2 logs
  ```
- **Khởi động lại toàn bộ**:
  ```bash
  pm2 restart all
  ```
- **Cấu hình tự khởi động cùng OS khi reboot máy chủ**:
  ```bash
  pm2 startup
  ```

---

## 🧩 Hướng dẫn Mở rộng Thêm Agent mới (VD: OpenClaw, Hermes...)

Cấu trúc hiện tại được thiết kế dạng mô-đun, rất dễ dàng để thêm bất kỳ Agent hay Web app mới nào vào quy trình deploy:

### Bước 1: Thêm dịch vụ vào `config/ecosystem.config.js`
Mở tệp [config/ecosystem.config.js](file:///home/sontv/code/AI/config/ecosystem.config.js) và thêm khai báo Agent mới vào mảng `apps`:

```javascript
    {
      name: 'openclaw',
      cwd: path.join(rootDir, 'openclaw'),
      script: 'pnpm',
      args: 'start --port 3090',
      interpreter: 'none',
      env: {
        NODE_ENV: 'production',
        PORT: 3090
      }
    },
    {
      name: 'hermes',
      cwd: path.join(rootDir, 'hermes'),
      script: 'node',
      args: 'server.js',
      env: {
        NODE_ENV: 'production',
        PORT: 3100
      }
    }
```

### Bước 2: Thêm tên miền và cấu hình Nginx trong `deploy.sh`
Trong `deploy.sh`, thêm khối sinh file Nginx cho Agent mới (trỏ tới cổng tương ứng, ví dụ `3090` hoặc `3100`):

```bash
OPENCLAW_DOMAIN="${OPENCLAW_DOMAIN:-openclaw.sontv.test}"

# Sinh file Nginx cho OpenClaw
cat <<EOF > "$NGINX_OUT_DIR/$OPENCLAW_DOMAIN.conf"
server {
    listen 80;
    server_name $OPENCLAW_DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:3090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF
```

Sau khi sửa, bạn chỉ cần chạy lại `./deploy.sh`, PM2 và Nginx sẽ tự động quản lý và khởi chạy toàn bộ các Agent mới.

EOF
