# Vendored Argo CD CRD schemas

Các schema này được vendored để `kubeconform` không phải tải từ nhánh `main` lúc chạy CI.

- Nguồn: `https://github.com/datreeio/CRDs-catalog`
- Commit nguồn: `784ec895547a36e548e6810b41f27baade3a0890`
- Ngày commit nguồn: `2026-11-17T12:23:33Z`
- Ngày lấy: `2026-11-18`
- Giấy phép repo nguồn: MIT

## Files

| File | Kích thước | SHA256 |
|---|---:|---|
| `argoproj.io/application_v1alpha1.json` | 423308 | `99c37877b0626eaf21f42f70f4fc432a4b820de548d88ed90cc75381adf5192c` |
| `argoproj.io/appproject_v1alpha1.json` | 19740 | `5b3f7b75f59e5821d06cedc6b0667b3f5a0d5efd2c9b6cb606cd4da40755a121` |

## Nguồn tải

- `https://raw.githubusercontent.com/datreeio/CRDs-catalog/784ec895547a36e548e6810b41f27baade3a0890/argoproj.io/application_v1alpha1.json`
- `https://raw.githubusercontent.com/datreeio/CRDs-catalog/784ec895547a36e548e6810b41f27baade3a0890/argoproj.io/appproject_v1alpha1.json`

## Cách dùng

Job `Kubeconform bootstrap` dùng template nội bộ:

```text
.github/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json
```

Không dùng `-ignore-missing-schemas` trong job này; schema thiếu hoặc không khớp phải làm job thất bại.
