# Kiến trúc GitOps

Tài liệu này mô tả luồng triển khai hiện có của Bagisto và Vault trên Argo CD, cùng các quy ước đang áp dụng. Mọi giá trị đều lấy từ manifest trong repo hoặc trạng thái chỉ đọc của cluster; phần chưa xác minh được liệt kê riêng ở cuối.

## 1. Luồng tổng quát

```mermaid
flowchart LR
  A["Push lên default branch"] --> B["CI: build, scan, test"]
  B --> C["Publish image lên GHCR (tag sha-7-hex)"]
  C --> D["update-gitops: sửa image tag trong overlays/dev"]
  D --> E["Bot push trực tiếp GITOPS_BRANCH (hiện tại master)"]
  E --> F["Argo CD poll repo định kỳ (~3 phút)"]
  F --> G["PreSync Job bagisto-migrate"]
  G --> H["Sync workload"]
```

- CI build/scan/test chạy cho push và pull request; job `publish` và `update-gitops` chỉ chạy khi push lên default branch của repo source.
- Bot hiện commit và push trực tiếp vào `GITOPS_BRANCH`; chưa mở PR. Chính sách chuyển sang PR được ghi ở [ADR 0001](adr/0001-repo-layout-and-conventions.md).
- Argo CD tự poll repo. Cluster hiện không đặt `timeout.reconciliation` trong `argocd-cm`; giá trị poll thực tế chưa được đo.

## 2. Sync wave và hook hiện có

Không có annotation `argocd.argoproj.io/sync-wave` trong `base/` hoặc `overlays/dev/`. Vì vậy mọi tài nguyên dưới đây dùng wave mặc định, trừ Job `bagisto-migrate` là hook `PreSync`.

| Tài nguyên | Kind | Sync wave | Hook | Ghi chú |
|---|---|---|---|---|
| `bagisto` | Namespace | Mặc định | Không | Cluster resource, nằm trong `clusterResourceWhitelist`. |
| `bagisto-config` | ConfigMap | Mặc định | Không | Cấu hình không nhạy cảm dùng chung cho web, worker, scheduler và Job migration. |
| `uploads` | PersistentVolumeClaim | Mặc định | Không | `ReadWriteOnce`, dung lượng `2Gi`; web, worker và Job migration cùng mount tại `storage/app/public`. |
| `web`, `redis`, `mysql` | Service | Mặc định | Không | — |
| `web`, `worker`, `scheduler`, `redis` | Deployment | Mặc định | Không | — |
| `mysql` | StatefulSet | Mặc định | Không | — |
| `bagisto-migrate` | Job | `PreSync` | `PreSync` | `hook-delete-policy: BeforeHookCreation,HookSucceeded`; `backoffLimit: 0`; `activeDeadlineSeconds: 1800`; `restartPolicy: Never`. |

Job `bagisto-migrate` chạy `php artisan migrate --force --no-interaction`, dùng cùng image app với overlay, nạp `bagisto-config` và `bagisto-app-secret`, và mount PVC `uploads` tại `/var/www/html/storage/app/public`. Job được xóa sau khi thành công; Job lỗi được giữ lại cho đến lần tạo hook tiếp theo.

## 3. Cấu hình Argo CD

Nguồn Bagisto: `bootstrap/application.yaml` và `bootstrap/appproject.yaml`. Vault dùng AppProject/Application riêng ở mục 4.

| Thành phần | Giá trị |
|---|---|
| Application | `bagisto`, namespace `argocd` |
| Project | `bagisto` |
| Source repo | `https://github.com/CuongMotNang/bagisto-gitops` |
| Target revision | `master` |
| Path | `overlays/dev` |
| Destination | `https://kubernetes.default.svc`, namespace `bagisto` |
| Automated sync | `prune: false`, `selfHeal: true` |
| Retry | `limit: 0` |
| Sync option | `PruneLast=true` |
| Finalizer | `resources-finalizer.argocd.argoproj.io` |
| AppProject sourceRepos | `https://github.com/CuongMotNang/bagisto-gitops` |
| AppProject destinations | namespace `bagisto`, server `https://kubernetes.default.svc` |
| Cluster resource whitelist | `{group: "", kind: Namespace}` |
| Namespace resource whitelist | `ConfigMap`, `Service`, `PersistentVolumeClaim`, `Deployment`, `StatefulSet`, `Job` |
| Orphaned resources | `warn: true` |

`bootstrap/` nằm ngoài `overlays/dev`, nên Application `bagisto` không tự quản lý AppProject/Application. Khi dựng lại cluster mới, áp dụng theo thứ tự ở mục 4 sau khi cài Argo CD và sau khi đã có Secret, MySQL, PVC.

## 4. Vault platform

Vault chạy bằng Application riêng, không nằm trong `overlays/dev`, nên không ảnh hưởng render hash của Bagisto.

Nguồn: `bootstrap/appproject-platform.yaml`, `bootstrap/application-vault.yaml`, `platform/vault/values.yaml`.

| Thành phần | Giá trị |
|---|---|
| Application | `vault`, namespace `argocd` |
| Project | `platform` |
| Chart | `hashicorp/vault` `0.34.1` |
| Image | `hashicorp/vault:2.0.4` |
| Mode | Standalone, 1 replica, Raft, PVC `1Gi`, StorageClass `standard` |
| Injector / CSI / UI | Tắt |
| Service | `ClusterIP`; không TLS |
| Values | `platform/vault/values.yaml` qua multiple sources `ref: values` |
| Destination | Namespace `vault`, server `https://kubernetes.default.svc` |
| Automated sync | `prune: false`, `selfHeal: true` |
| Retry | `limit: 0` |
| Sync option | `CreateNamespace=true` |
| AppProject sourceRepos | GitOps repo và `https://helm.releases.hashicorp.com` |
| Cluster resource whitelist | `Namespace`, `rbac.authorization.k8s.io/ClusterRoleBinding` |
| Namespace resource whitelist | `ConfigMap`, `Service`, `ServiceAccount`, `StatefulSet` |

Chart `0.34.1` được phát hành ngày 2026-08-13; image `2.0.4` phát hành ngày 2026-08-04. Cả hai đều cũ hơn 14 ngày tại thời điểm thêm cấu hình.

`helm template` với values hiện tại chỉ tạo một tài nguyên cluster-scoped ngoài Namespace: `ClusterRoleBinding/vault-server-binding` cho `system:auth-delegator`. Injector tắt nên không có `MutatingWebhookConfiguration` hoặc `caBundle`; vì vậy chưa cần `ignoreDifferences`. Nếu bật injector sau này, phải thêm ignore cho `caBundle` của webhook.

Vault ở trạng thái sealed sau khi cài. ReadinessProbe dùng `/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204`, nên pod vẫn Ready khi Vault sealed hoặc chưa init; Application không bị Degraded vô thời hạn. Unseal vẫn là thao tác tay, xem [runbook Vault](runbooks/vault-unseal.md).

Thứ tự bootstrap khi dựng lại cluster:

```bash
kubectl apply -f bootstrap/appproject.yaml
kubectl apply -f bootstrap/application.yaml
kubectl apply -f bootstrap/appproject-platform.yaml
kubectl apply -f bootstrap/application-vault.yaml
```

## 5. Bot cập nhật GitOps

Nguồn: workflow `ci` trong repo source `CuongMotNang/bagisto`, file `.github/workflows/ci.yaml`, job `update-gitops`.

- Job `update-gitops` phụ thuộc `publish` và chỉ chạy khi push lên default branch.
- Biến cấu hình: `GITOPS_REPOSITORY` (bắt buộc), `GITOPS_BRANCH` (mặc định `master`), `GITOPS_OVERLAY_DIR` (mặc định `overlays/dev`).
- Secret: `GITOPS_TOKEN`, dùng để checkout và push GitOps repo.
- Image được publish với tag `sha-${GITHUB_SHA::7}`; app và web phải cùng tag.
- Bot checkout GitOps repo tại `GITOPS_BRANCH`, chạy `kustomize edit set image`, kiểm tra chỉ `overlays/dev/kustomization.yaml` thay đổi, commit với message `chore(gitops): update bagisto image to sha-<7>`, rồi fetch/rebase và push trực tiếp lên `GITOPS_BRANCH`. Vòng push có tối đa 3 lần thử.
- Bot hiện không sửa `bootstrap/` hoặc `platform/` và không chạy migration; migration do hook `PreSync` của Argo CD thực hiện.

## 6. Rủi ro đã biết

- **PVC `uploads` là `ReadWriteOnce`.** Web, worker và Job migration cùng mount một PVC. Trên cluster nhiều node, pod có thể bị kẹt scheduling nếu volume đang được node khác giữ; cần RWX hoặc object storage (S3/MinIO) khi mở rộng.
- **Thay đổi ConfigMap cùng revision không có hiệu lực trong PreSync.** Job `bagisto-migrate` đọc `bagisto-config` hiện có trên cluster trước khi Argo chạy phase Sync. Nếu migration cần biến môi trường mới trong cùng revision, Job sẽ dùng giá trị cũ.
- **Private storage là ephemeral.** Chỉ `storage/app/public` được mount từ PVC. `storage/app/private` không có volume riêng; scheduler cũng không mount PVC. Dữ liệu private sẽ mất khi pod bị thay thế.
- **Migration phải tương thích ngược.** PreSync chạy trước khi workload mới được Sync; trong thời gian rollout, pod cũ vẫn có thể phục vụ. Migration không được làm hỏng code cũ và cần có kế hoạch rollback.
- **Vault sealed sau khi cài hoặc sau khi pod restart.** ReadinessProbe được cấu hình để pod vẫn Ready khi sealed, nhưng Vault không phục vụ secret cho đến khi unseal tay. Không có auto-unseal.
- **Vault dùng 1 key share, threshold 1.** Đây là đánh đổi chỉ cho Minikube dev: mất key là mất khả năng unseal; lộ key là có thể unseal. Key và root token phải nằm trong password manager, không vào repo.
- **Vault không bật TLS.** Traffic chỉ trong cluster qua Service `ClusterIP`; không dùng cấu hình này cho môi trường có traffic bên ngoài cluster.
- **Vault chạy 1 replica, PVC Raft `ReadWriteOnce`.** Không có HA; pod restart cần unseal lại. Mất PVC là mất dữ liệu Vault.
- **Vault có một ClusterRoleBinding.** `vault-server-binding` gắn `system:auth-delegator` cho service account `vault`; cần thiết nếu dùng Vault Kubernetes auth.

## 7. Chưa xác minh

- Thời gian poll thực tế của Argo CD. `argocd-cm` không có `timeout.reconciliation`; giá trị mặc định khoảng 180 giây chưa được đo trên cluster.
- Cấu hình branch protection thực tế trên GitHub. Repo không lưu cấu hình này.
- Quyền, phạm vi và thời hạn của secret `GITOPS_TOKEN`; không đọc giá trị secret.
- Cấu hình backup/restore cho MySQL và PVC `uploads`; repo hiện không có manifest cho việc này.
- Vault chưa được cài thật, chưa init/unseal, và chưa kiểm chứng hành vi Application khi pod restart. Các kết luận về readiness dựa trên `helm template` và tài liệu `/sys/health` của HashiCorp.
- Chưa quan sát OutOfSync thực tế của Vault. Không khai báo `ignoreDifferences` vì injector tắt và không có webhook; nếu bật injector, cần kiểm tra lại `caBundle`.
