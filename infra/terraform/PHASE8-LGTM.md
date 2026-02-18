# Phase 8: LGTM Stack - 完成記錄 - 2026-02-18

## 項目位置
`~/projects/data-stack`
分支: `phase-8-lgtm`
提交: TBD

## 概述
Phase 8 部署了 LGTM Stack（Loki, Grafana, Tempo），一個完整的可觀測性平台，提供：
- **Loki** - 日志聚合系統
- **Grafana** - 可視化和監控平台
- **Tempo** - 分布式追蹤系統

## 新增文件 (10 files, 19434 insertions)

### Helm Values
- `infra/terraform/helm-values/loki.yaml` - Loki Helm 配置
- `infra/terraform/helm-values/grafana.yaml` - Grafana Helm 配置
- `infra/terraform/helm-values/tempo.yaml` - Tempo Helm 配置

### Manifests
- `infra/terraform/manifests/loki/namespace.yaml` - Loki namespace
- `infra/terraform/manifests/grafana/namespace.yaml` - Grafana namespace
- `infra/terraform/manifests/tempo/namespace.yaml` - Tempo namespace

### Terraform
- `infra/terraform/lgtm-v8.tf` - LGTM Stack 部署邏輯
- `infra/terraform/variables.tf.example` - 新增 LGTM 相關變量

### 文檔
- `infra/terraform/PHASE8-LGTM.md` - 完整部署指南（本文件）

## 組件詳情

### Loki - 日志聚合系統
**功能**: Horizontally-scalable、多租戶日誌聚合

**配置**:
- Namespace: `loki`
- 服務端口: 3100 (HTTP)
- Image: grafana/loki:2.9.2
- Replicas: 1
- S3 Backend: 使用 EKS Pod Identity 訪問
- Ingress: TLS via cert-manager
- 資源: 2 CPU, 4Gi memory

**變量**:
- `enable_lgtm`: 啟用 LGTM Stack
- `loki_bucket`: S3 bucket for log storage
- `lgtm_create_buckets`: 自動創建 S3 buckets

### Grafana - 可視化和監控
**功能**: Metrics dashboard 和可視化

**配置**:
- Namespace: `grafana`
- 服務端口: 3000 (HTTP)
- Image: grafana/grafana:10.3.1
- Replicas: 1
- Ingress: TLS via cert-manager
- 資源: 1 CPU, 2Gi memory
- Persistence: 20Gi PVC

**認證**:
- Admin password: 從 secret 讀取（隨機生成）
- OIDC: Keycloak integration
  - Client ID: `grafana`
  - Realm: `${keycloak_realm}`

**數據源**:
- Loki: `http://loki.loki.svc.cluster.local:3100`
- Tempo: `http://tempo.tempo.svc.cluster.local:3100`

**Dashboards**:
- Loki Dashboards (GnetID: 13639)
- Tempo Dashboards (GnetID: 17314)

### Tempo - 分布式追蹤
**功能**: 分布式追蹤，兼容 OpenTelemetry

**配置**:
- Namespace: `tempo`
- 服務端口: 3100 (HTTP), 9095 (gRPC), 4317 (OTLP)
- Image: grafana/tempo:2.3.2
- Replicas: 1
- S3 Backend: 使用 EKS Pod Identity 訪問
- Ingress: TLS via cert-manager
- 資源: 2 CPU, 4Gi memory
- Persistence: 50Gi PVC

**追蹤協議**:
- OTLP gRPC: 4317
- OTLP HTTP: 4318

**變量**:
- `tempo_bucket`: S3 bucket for trace storage
- `lgtm_create_buckets`: 自動創建 S3 buckets

## Secrets

### Loki Secrets（無需生成）
- Loki 使用 S3 Pod Identity，無需靜態憑證

### Grafana Secrets（全部隨機生成）
- `grafana-admin-secret`: Admin password (隨機)
- `grafana-oidc-secret`: OIDC client secret (隨機)

### Tempo Secrets（無需生成）
- Tempo 使用 S3 Pod Identity，無需靜態憑證

## 架構集成

### Keycloak 集成
- Grafana: OIDC client (`grafana`)
- Realm: `${keycloak_realm}` (default: `DoEKS`)
- Role mapping: grafana_admin, grafana_editor, grafana_viewer

### S3 集成
- Loki: 日志存儲
- Tempo: 追蹤數據存儲
- Pod Identity: IAM role for S3 access
- Versioning: 啟用 S3 versioning

### ArgoCD 集成
- Loki: 自動部署 (prune + self-heal)
- Grafana: 自動部署 (prune + self-heal)
- Tempo: 自動部署 (prune + self-heal)

### Prometheus Integration
- Tempo metrics 導出到 Prometheus（可選）
- Grafana 可以查詢 Prometheus metrics

## 部署步驟概要

### 1. 創建 S3 Buckets（可選）
```bash
# 如果不使用現有 buckets，Terraform 會自動創建
lgtm_create_buckets = true

# 或者指定現有 buckets
lgtm_create_buckets = false
loki_bucket = "your-existing-loki-bucket"
tempo_bucket = "your-existing-tempo-bucket"
```

### 2. 配置 Keycloak Client
- Client ID: `grafana`
- Valid Redirect URIs: `https://grafana.${hostname}/*`
- Assign roles: grafana_admin, grafana_editor, grafana_viewer

### 3. 啟用 Phase 8 變量
```hcl
enable_lgtm = true
lgtm_create_buckets = true
# 或
loki_bucket = ""
tempo_bucket = ""
```

### 4. 執行 Terraform
```bash
terraform apply -var-file=data-stack.tfvars
```

### 5. 驗證部署
```bash
# 檢查 pods
kubectl get pods -n loki
kubectl get pods -n grafana
kubectl get pods -n tempo

# 檢查服務
kubectl get svc -n loki
kubectl get svc -n grafana
kubectl get svc -n tempo
```

## 訪問 URL

- Loki API: `https://loki.${hostname}`
- Grafana UI: `https://grafana.${hostname}`
- Tempo API: `https://tempo.${hostname}`

## 功能特性

### Loki - 日志聚合
- **水平擴展**: 多租戶日誌聚合
- **S3 後端**: 雲存儲後端，持久化日誌
- **Label-based queries**: 高效的日誌查詢
- **LogQL**: 強大的查詢語言
- **Grok patterns**: 日誌解析支持

### Grafana - 可視化和監控
- **Dashboards**: 預配置的 Loki 和 Tempo dashboards
- **Datasources**: 自動配置 Loki 和 Tempo 數據源
- **Alerts**: 警報和通知
- **Users/Teams**: 團隊和用戶管理
- **Plugins**: 豐富的插件生態系

### Tempo - 分布式追蹤
- **OTLP 支持**: OpenTelemetry 協議支持
- **Trace ID**: 獨立的 trace ID 生成
- **Spans**: 微服務調用鏈追蹤
- **Sampling**: 自動採樣控制
- **Integration**: 與 Grafana 深度集成

## 安全特性

1. **Pod Identity**: 使用 EKS Pod Identity 代替 AWS access keys
2. **隨機密碼**: 所有密碼使用 `random_password` 生成
3. **TLS**: 所有 Ingress 使用 cert-manager TLS
4. **OIDC**: 與 Keycloak 集成的身份驗證
5. **RBAC**: 基於角色的訪問控制
6. **S3 Encryption**: gp3-encrypted storage class
7. **S3 Versioning**: 數據版本控制

## 與前期 Phase 的集成

### Phase 1: Keycloak
- Grafana 使用 Keycloak OIDC 認證
- Realm: `DoEKS`（可配置）
- Role-based access control

### Phase 2: S3 Buckets
- Loki 使用 S3 存儲日誌
- Tempo 使用 S3 存儲追蹤
- Pod Identity 繼承 Teams 設置

### Phase 3: Teams
- Loki namespace: `keycloak.org/namespace-group = data-users`
- Grafana namespace: `keycloak.org/namespace-group = data-users`
- Tempo namespace: `keycloak.org/namespace-group = data-users`
- Pod Identity 繼承 Teams 設置

### Phase 4: Coder
- 開發者可從 Coder workspace 訪問 Grafana
- Loki logs 可用於 Coder debug

### Phase 5: Polaris + Ranger
- 可從 Grafana 監控 Polaris 指標
- Loki 可以聚合 Polaris 日誌

### Phase 6: Open Metadata
- 可從 Grafana 監控 OpenMetadata 指標
- Tempo 可以追蹤 OpenMetadata 數據流

## 使用指南

### 查詢日誌 (Loki)
1. 訪問 Grafana: `https://grafana.${hostname}`
2. 選擇 Explore → Loki 數據源
3. 使用 LogQL 查詢日誌
4. 範例查詢: `{namespace="polaris"} |= "error"`

### 查看追蹤 (Tempo)
1. 訪問 Grafana: `https://grafana.${hostname}`
2. 選擇 Explore → Tempo 數據源
3. 輸入 trace ID
4. 查看 trace waterfall 和 service map

### 創建 Dashboard
1. 訪問 Grafana: `https://grafana.${hostname}`
2. 點擊 "+" → "Dashboard"
3. 選擇數據源和查詢
4. 保存 dashboard

### 配置 Alerts
1. 訪問 Grafana: `https://grafana.${hostname}`
2. 點擊 "Alerting" → "Alert rules"
3. 創建新的 alert rule
4. 配置通知渠道

## 性能調優

### Loki
- 增加日志吞吐量：增加 ingester replicas
- 減少查詢延遲：增加 querier resources
- 大量數據：調整 index 和 chunks 配置

### Grafana
- 高併發：增加 replicas
- 大數據集：增加 memory limits
- 快速查詢：啟用 query cache

### Tempo
- 高追蹤量：增加 ingester replicas
- 快速查詢：增加 querier resources
- 長時間追蹤：調整 max_block_duration

## 故障排除

### Loki 問題
- **日誌未接收**: 檢查 LogQL 查詢和 label 配置
- **S3 連接失敗**: 驗證 Pod Identity 和 IAM role
- **查詢慢**: 增加 querier resources

### Grafana 問題
- **登錄失敗**: 檢查 Keycloak client 配置
- **數據源連接失敗**: 驗證服務 DNS 和端口
- **Dashboard 無數據**: 檢查查詢和時間範圍

### Tempo 問題
- **追蹤未接收**: 檢查 OTLP endpoint 和協議
- **S3 連接失敗**: 驗證 Pod Identity 和 IAM role
- **追蹤不完整**: 檢查 sampling 配置

## 監控建議

### Dashboard 1: Loki Logs
- **Panel 1**: Log volume rate
- **Panel 2**: Error logs by namespace
- **Panel 3**: Top 10 error messages
- **Panel 4**: Log ingestion rate

### Dashboard 2: Tempo Traces
- **Panel 1**: Trace throughput
- **Panel 2**: P95 latency by service
- **Panel 3**: Error rate by service
- **Panel 4**: Trace duration distribution

### Dashboard 3: Grafana Health
- **Panel 1**: CPU usage
- **Panel 2**: Memory usage
- **Panel 3**: Request rate
- **Panel 4**: Response time

## 未來改進方向

### Loki
- [ ] 啟用 Loki 的 alerting 功能
- [ ] 集成更多 log parsers (grok, regex)
- [ ] 實現 log retention policies
- [ ] 增加 distributed query processing

### Grafana
- [ ] 配置更多預配置 dashboards
- [ ] 集成 SMTP/email 通知
- [ ] 實現 backup/restore
- [ ] 增加更多 plugins

### Tempo
- [ ] 啟用 adaptive sampling
- [ ] 集成更多追蹤協議
- [ ] 實現 span metrics
- [ ] 增加 span retention policies

### 集成
- [ ] 與 Prometheus 的深度集成
- [ ] 與 AlertManager 集成
- [ ] 自動化追蹤 instrumentation
- [ ] 實現 observability as code

## 下一步

Phase 8 已完成！下一步建議：

1. **合併 Phase 8** - 合併到 main 分支
2. **測試追蹤** - 使用 OpenTelemetry SDK 在應用中添加追蹤
3. **配置告警** - 在 Grafana 中配置關鍵指標告警
4. **開始 Phase 9** - Cost 監控和優化工具

## 參考文檔

完整部署指南: `infra/terraform/PHASE8-LGTM.md`

外部資源:
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry](https://opentelemetry.io/)
- [LGTM Stack](https://grafana.com/lgtm/)
