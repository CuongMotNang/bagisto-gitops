# bagisto-gitops (lớp 1: MySQL + Redis trên Minikube)

## Chạy thử
```
minikube start --cpus=4 --memory=6144        # chỉnh theo máy của bạn

kubectl apply -f base/namespace.yaml

# Secret tạo bằng tay, KHÔNG commit vào Git (sau này Vault + External Secrets thay thế)
# MYSQL_USER không được là root
kubectl -n bagisto create secret generic bagisto-secrets \
  --from-literal=MYSQL_ROOT_PASSWORD='đổi-mật-khẩu-1' \
  --from-literal=MYSQL_DATABASE='bagisto' \
  --from-literal=MYSQL_USER='bagisto' \
  --from-literal=MYSQL_PASSWORD='đổi-mật-khẩu-2'

kubectl apply -k overlays/dev
kubectl -n bagisto get pods -w
```

## Kiểm tra
```
kubectl -n bagisto exec -it mysql-0 -- sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;"'
kubectl -n bagisto exec deploy/redis -- redis-cli ping
```

## Thử mất pod (dữ liệu MySQL phải còn)
```
kubectl -n bagisto delete pod mysql-0
kubectl -n bagisto get pods -w     # pod mới lên, gắn lại PVC cũ
```