# Bootstrap Argo CD cho Bagisto và Vault

Thư mục này chứa AppProject và Application được tạo tay trên cluster, đưa vào Git để dựng lại cluster mới mà không mất cấu hình Argo CD.

Các file ở đây **không** nằm trong path `overlays/dev`, nên Application `bagisto` không tự quản lý chúng. Application `vault` cũng không nằm trong `overlays/dev`; Vault được cài từ Helm chart qua Application riêng.

## Điều kiện trước khi chạy

- Argo CD đã được cài trong namespace `argocd`.
- Bagisto: namespace `bagisto`, MySQL, Redis và PVC `uploads` phải tồn tại trước lần sync đầu để hook `PreSync` có dependency; overlay có khai báo các tài nguyên này nhưng `PreSync` chạy trước phase Sync.
- Bagisto: Secret `bagisto-app-secret` và `bagisto-secrets` đã được tạo tay theo hướng dẫn ở README gốc. Không commit Secret vào Git.
- Vault: StorageClass mặc định `standard` tồn tại và có thể cấp PVC. Application dùng `CreateNamespace=true` để tạo namespace `vault`.

## Thứ tự áp dụng

Bagisto:

```bash
kubectl apply -f bootstrap/appproject.yaml
kubectl apply -f bootstrap/application.yaml
```

Vault:

```bash
kubectl apply -f bootstrap/appproject-platform.yaml
kubectl apply -f bootstrap/application-vault.yaml
```

Nếu dựng cả hai, áp dụng theo thứ tự trên: AppProject trước Application tương ứng. Không dựa vào `kubectl apply -f bootstrap/` vì thứ tự file không đảm bảo AppProject có trước Application.

Sau khi `application-vault` được sync, Vault ở trạng thái sealed. Làm theo [runbook unseal](../docs/runbooks/vault-unseal.md); không commit unseal key hoặc root token.
