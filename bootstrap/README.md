# Bootstrap Argo CD cho Bagisto

Thư mục này chứa AppProject và Application được tạo tay trên cluster, đưa vào Git để dựng lại cluster mới mà không mất cấu hình Argo CD.

Các file ở đây **không** nằm trong path `overlays/dev`, nên Application `bagisto` không tự quản lý chúng.

## Điều kiện trước khi chạy

- Argo CD đã được cài trong namespace `argocd`.
- Namespace `bagisto`, MySQL, Redis và PVC `uploads` đã tồn tại (các thành phần này hiện không được quản lý trong repo này).
- Secret `bagisto-app-secret` và `bagisto-secrets` đã được tạo tay theo hướng dẫn ở README gốc. Không commit Secret vào Git.

## Cách chạy

```bash
kubectl apply -f bootstrap/appproject.yaml
kubectl apply -f bootstrap/application.yaml
```

Có thể dùng `kubectl apply -f bootstrap/` để áp dụng cả hai; nên áp dụng AppProject trước để Application tham chiếu đúng project ngay từ đầu.
