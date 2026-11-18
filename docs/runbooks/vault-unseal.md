# Runbook: init và unseal Vault

Runbook này dành cho Vault standalone 1 replica trên Minikube dev. Vault dùng Raft với PVC `data-vault-0`; sau khi cài hoặc sau mỗi lần pod restart, Vault ở trạng thái sealed và phải unseal tay.

## Lưu ý an toàn

- `vault operator init` chỉ chạy **một lần** khi Vault chưa được init. Chạy lại trên Vault đã init sẽ lỗi; không xóa PVC để init lại nếu chưa chấp nhận mất dữ liệu.
- Kết quả init chứa unseal key và root token. Lưu cả hai trong password manager; **không** commit vào repo, không dán vào issue/chat, không ghi vào shell history.
- Cấu hình dùng `-key-shares=1 -key-threshold=1` chỉ cho Minikube dev. Đây là đánh đổi: một key duy nhất vừa đủ để unseal; mất key là mất khả năng unseal, lộ key là có thể unseal.
- Không xóa PVC `data-vault-0` để “làm lại”; thao tác đó xóa toàn bộ dữ liệu Vault.

## Kiểm tra trạng thái

```bash
kubectl -n vault get pods
kubectl -n vault exec vault-0 -- vault status || true
kubectl -n argocd get application vault
```

`vault status` trả exit code `0` khi đã unseal, `2` khi sealed. ReadinessProbe của chart trả `204` cho sealed/uninitialized nên pod vẫn `Ready` và Application không bị Degraded vô thời hạn; điều này không có nghĩa Vault đã sẵn sàng phục vụ secret.

## Init lần đầu

Chỉ chạy khi `vault status` báo `Initialized: false`.

```bash
kubectl -n vault exec -it vault-0 -- vault operator init -key-shares=1 -key-threshold=1
```

Lưu `Unseal Key 1` và `Initial Root Token` vào password manager. Có thể dùng `-format=json` nếu cần chuyển kết quả vào password manager, nhưng không lưu file kết quả trong repo hoặc thư mục dùng chung.

Sau khi lưu, unseal:

```bash
kubectl -n vault exec -it vault-0 -- vault operator unseal
```

Nhập unseal key tại prompt. Với threshold `1`, chỉ cần một lần.

## Unseal sau khi pod restart

Pod restart hoặc cluster khởi động lại làm Vault sealed lại. PVC vẫn giữ dữ liệu; không chạy lại `operator init`.

```bash
kubectl -n vault get pods
kubectl -n vault exec -it vault-0 -- vault operator unseal
kubectl -n vault exec vault-0 -- vault status
```

Kiểm tra kết quả:

```bash
kubectl -n vault get pods
kubectl -n vault logs vault-0 --tail=50
kubectl -n argocd get application vault
```

`vault status` phải trả `Sealed: false` và exit code `0`. Nếu pod không lên, xem log và sự kiện:

```bash
kubectl -n vault describe pod vault-0
kubectl -n vault get pvc data-vault-0
```

## Khi nào cần init lại

Chỉ init lại khi PVC `data-vault-0` bị mất hoặc dữ liệu Vault không còn và đã chấp nhận mất toàn bộ secret. Trước khi làm, xác nhận lại với người phụ trách; không tự động xóa PVC.
