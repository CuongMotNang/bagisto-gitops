# bagisto-gitops

## Prerequisites cho migration Job

Argo CD chạy `Job/bagisto-migrate` ở hook `PreSync` trước khi apply các Deployment. Job giả định các tài nguyên sau đã tồn tại và sẵn sàng trước khi sync:

- `StatefulSet/mysql` và `Service/mysql` đã Ready.
- PVC `uploads` đã tồn tại.
- ConfigMap `bagisto-config` đã tồn tại.
- Secret `bagisto-app-secret` đã tồn tại.
- AppProject `bagisto` cho phép tài nguyên `batch/Job`.
- Application `bagisto` đặt `spec.syncPolicy.retry.limit: 0`.

Fresh-cluster bootstrap nằm ngoài scope của migration Job này. Trên cluster mới, phải tạo MySQL, PVC, ConfigMap và Secret trước khi Argo CD thực hiện sync đầu tiên.

## Lớp 1: MySQL + Redis

```bash
minikube start --cpus=4 --memory=6144
kubectl apply -f base/namespace.yaml
kubectl -n bagisto create secret generic bagisto-secrets \
  --from-literal=MYSQL_ROOT_PASSWORD='...' \
  --from-literal=MYSQL_DATABASE='bagisto' \
  --from-literal=MYSQL_USER='bagisto' \
  --from-literal=MYSQL_PASSWORD='...'
```

`bagisto-secrets` chỉ dùng cho MySQL. Không commit giá trị secret vào Git.

## Lớp 2: Bagisto

1. Giữ nguyên cơ chế image tag trong `overlays/dev/kustomization.yaml`; CI cập nhật tag `sha-<7 ký tự>` cho cả app và web.
2. Tạo Secret cho app. `DB_PASSWORD` phải trùng `MYSQL_PASSWORD`; `REDIS_PASSWORD` được Redis và app dùng chung.

```bash
kubectl -n bagisto create secret generic bagisto-app-secret \
  --from-literal=APP_KEY="base64:$(openssl rand -base64 32)" \
  --from-literal=DB_DATABASE='bagisto' \
  --from-literal=DB_USERNAME='bagisto' \
  --from-literal=DB_PASSWORD='...' \
  --from-literal=REDIS_PASSWORD='...'
```

3. Áp dụng và theo dõi:

```bash
kubectl apply -k overlays/dev
kubectl -n bagisto get pods -w
```

4. Fresh cluster: cài Bagisto một lần bằng installer. Lệnh này tạo mới database và không được chạy trên dữ liệu thật.

```bash
kubectl -n bagisto exec deploy/web -c app -- php artisan bagisto:install --no-interaction
```

Trên cluster đã có dữ liệu, không chạy `bagisto:install`. Migration được thực hiện tự động bởi `Job/bagisto-migrate` ở hook `PreSync` với lệnh `php artisan migrate --force --no-interaction`.

5. Mở thử:

```bash
kubectl -n bagisto port-forward svc/web 8080:80
```

Mở `http://localhost:8080` và `http://localhost:8080/admin`.

## Migration Job

Job dùng chính image app với tag bất biến từ `overlays/dev/kustomization.yaml`, tái sử dụng ConfigMap `bagisto-config` và Secret `bagisto-app-secret`.

Job mount PVC `uploads` tại `/var/www/html/storage/app/public` vì migration `2026_09_23_180000_move_storage_into_plural_directories` và `2026_08_15_000006_move_theme_uploads_to_section_directory` có thao tác file trên public disk. Private disk hiện không được PVC-backed và đang rỗng, nên Job không mount thêm private storage. Nếu sau này private storage được chuyển sang PVC, phải cập nhật Job tương ứng.

Job đặt `backoffLimit: 0`; Kubernetes không retry container. Application phải đặt `syncPolicy.retry.limit: 0` để Argo CD không tự retry sync thất bại. Khi migration thất bại, Job được giữ lại để lấy log; người vận hành phải điều tra trước khi chạy `argocd app sync bagisto` thủ công.

Job không chạy `bagisto:install`, không chạy seed, không chạy `migrate:fresh`, và không thay đổi database ngoài các migration đang chờ.

## Kiểm tra

```bash
kubectl -n bagisto logs deploy/web -c app --tail=30
kubectl -n bagisto logs deploy/web -c nginx --tail=30
kubectl -n bagisto logs deploy/worker --tail=30
kubectl -n bagisto logs deploy/scheduler --tail=30
kubectl -n bagisto logs job/bagisto-migrate --tail=200
```
