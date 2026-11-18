# 0001 — Bố cục repo và quy ước vận hành

- Trạng thái: Accepted
- Ngày: 2026-11-18

## Bối cảnh

Repo GitOps hiện có `base/` và `overlays/dev/` ở thư mục gốc, vừa bổ sung `bootstrap/` cho AppProject và Application. Bot cập nhật image trong repo source đang commit và push trực tiếp vào `master`. Nhãn workload chưa thống nhất đầy đủ, chưa có quy định branch protection, và các thay đổi cluster có thể bị sửa tay ngoài Git.

Các quyết định dưới đây chốt hướng đi cho Giai đoạn 0. PR này chỉ ghi tài liệu; chưa di chuyển thư mục, chưa đổi manifest và chưa đổi cấu hình GitHub.

## Quyết định

### 1. Bố cục repo đích

Bố cục đích:

```text
apps/bagisto/{base,overlays/dev}
bootstrap/
docs/
scripts/
.github/
```

- `bootstrap/` chứa AppProject và Application, nằm ngoài path Application theo dõi.
- `docs/` chứa kiến trúc và ADR.
- `scripts/` dành cho script vận hành có thể kiểm chứng và tái sử dụng.
- `.github/` chứa CODEOWNERS, PR template và workflow.

Hiện trạng chưa di chuyển: `base/` và `overlays/dev/` vẫn ở gốc repo. Việc chuyển sang `apps/bagisto/` phải cập nhật `bootstrap/application.yaml`, biến `GITOPS_OVERLAY_DIR` của bot và tài liệu liên quan.

### 2. Nhãn chuẩn

Giữ các nhãn hiện có:

- `app.kubernetes.io/name`
- `app.kubernetes.io/component`
- `app.kubernetes.io/part-of`

Bổ sung:

- `owner: cuongmotnang`
- `env: dev`
- `app.kubernetes.io/managed-by: argocd`

Chỉ gắn nhãn bằng `labels` của Kustomize với `includeSelectors: false`. Cấm dùng `commonLabels` vì có thể làm đổi selector và gây lỗi immutable.

Áp dụng hai bước:

1. Gắn nhãn vào metadata của tài nguyên trước, không đụng selector và pod template.
2. Gắn nhãn vào pod template sau. Bước này làm thay đổi pod template nên sẽ gây rollout; cần chủ động thời điểm.

### 3. Chính sách bot

Chuyển `update-gitops` từ commit/push trực tiếp sang mở PR vào `GITOPS_BRANCH`, chờ CI xanh rồi merge. Bot không được push thẳng `master`.

### 4. Branch protection

Bắt buộc:

- Có pull request.
- CI xanh.
- 0 reviewer.
- Áp dụng cả admin.

Cấu hình này nằm trên GitHub, không nằm trong repo.

### 5. Chính sách CI

Job CI mới chạy ở chế độ báo cáo trước, sau đó chuyển sang chặn ở PR F. Không đổi tên các job CI đã có để tránh làm mất required check.

### 6. Thay đổi cấu hình cluster

Mọi thay đổi cấu hình cluster phải có commit trong GitOps repo. Không dùng `kubectl patch`, `kubectl edit` hoặc sửa trực tiếp trên cluster.

## Hệ quả

- Việc chuyển bố cục sang `apps/bagisto/` cần một PR riêng và phải cập nhật đồng bộ Application path, `GITOPS_OVERLAY_DIR`, CI và tài liệu.
- Bước gắn nhãn pod template sẽ gây rollout; `includeSelectors: false` tránh đổi selector nhưng không tránh rollout.
- Bot mở PR cần `GITOPS_TOKEN` có quyền tạo PR và cần branch protection được cấu hình đúng; nếu thiếu, bot sẽ không merge được.
- CI báo cáo trước chưa chặn merge; chỉ có hiệu lực chặn khi chuyển sang PR F.
- Cấm sửa trực tiếp cluster làm thao tác khẩn cấp chậm hơn, nhưng đổi lại mọi thay đổi đều truy vết được và không tạo drift.
