# bagisto-gitops

## Lớp 1: MySQL + Redis (đã chạy)
```
minikube start --cpus=4 --memory=6144
kubectl apply -f base/namespace.yaml
kubectl -n bagisto create secret generic bagisto-secrets \
  --from-literal=MYSQL_ROOT_PASSWORD='...' --from-literal=MYSQL_DATABASE='bagisto' \
  --from-literal=MYSQL_USER='bagisto' --from-literal=MYSQL_PASSWORD='...'
```gghghhjlkj bbb  
]



\]p;9ijtfgm B HYUUUUUUY                                                                                                                       

## Lớp 2: Bagisto (web, worker, scheduler)

1. Sửa tag image trong `overlays/dev/kustomization.yaml` (thay `sha-REPLACE`).
   Nhớ kiểm tra tên image `ghcr.io/cuongmotnang/...` khớp với package thật trên GHCR.
2. Tạo secret thứ hai cho app (DB_PASSWORD phải TRÙNG MYSQL_PASSWORD ở trên):
```
kubectl -n bagisto create secret generic bagisto-app-secret \
  --from-literal=APP_KEY="base64:$(openssl rand -base64 32)" \
  --from-literal=DB_DATABASE='bagisto' \
  --from-literal=DB_USERNAME='bagisto' \
  --from-literal=DB_PASSWORD='...'
```
3. Áp dụng và theo dõi:
```
kubectl apply -k overlays/dev
kubectl -n bagisto get pods -w
```
4. **Cài Bagisto một lần** (XOÁ SẠCH database rồi tạo mới, KHÔNG chạy lại trên dữ liệu thật):
```
kubectl -n bagisto exec deploy/web -c app -- php artisan bagisto:install --no-interaction
```
   Tài khoản admin mặc định theo tài liệu Bagisto là admin@example.com / admin123, đổi ngay sau khi đăng nhập.
5. Mở thử:
```
kubectl -n bagisto port-forward svc/web 8080:80
# http://localhost:8080  và  http://localhost:8080/admin
```

## Kiểm tra
```
kubectl -n bagisto logs deploy/web -c app --tail=30
kubectl -n bagisto logs deploy/web -c nginx --tail=30
kubectl -n bagisto logs deploy/worker --tail=30
kubectl -n bagisto logs deploy/scheduler --tail=30
```