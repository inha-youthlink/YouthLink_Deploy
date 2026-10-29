# YouthLink_Deploy

YouthLink 앱 4개(RAG, 프론트, ETL, 평가)를 EC2 단일 노드 k3s에 배포하는 저장소입니다. 앱 저장소는 소스코드만 관리하고, 이미지 빌드·매니페스트·일반 설정·배포는 모두 여기서 합니다.

계획과 결정 이유는 `docs/배포계획.md`를 참고합니다.

## 구조

| 경로 | 내용 |
| --- | --- |
| `apps/<앱>/` | 이미지 빌드용 Dockerfile (빌드 컨텍스트는 앱 저장소) |
| `k8s/<앱>/base/` | 리소스별 기본 yaml (deployment, service, cronjob, job) |
| `k8s/<앱>/overlays/prod/` | 이미지 태그, 일반 설정(`config.env`) |
| `.github/workflows/` | `deploy.yml`(빌드·배포), `evaluate.yml`(평가 실행) |

## 배포 (GitHub Actions, 수동 실행)

| workflow | 입력 | 동작 |
| --- | --- | --- |
| deploy | `app`: `rag`·`front`·`etl`·`ragas-eval`·`common`, `ref`: 앱 저장소 브랜치·커밋, `build`: 이미지 빌드 여부 | 빌드 → GHCR(`ghcr.io/inha-youthlink/youthlink-<app>`) push → 이미지 태그 커밋 → `kubectl apply -k k8s/<app>/overlays/prod` (`ragas-eval`은 적용하지 않음) |
| evaluate | `command`: `run`·`route`·`baseline` | 이전 평가 Job 삭제 → 평가 Job 적용 (LLM 비용 발생) |

설정만 바꿀 때는 `k8s/<앱>/overlays/prod/config.env`를 커밋한 뒤 deploy를 `build: false`로 실행합니다.

## 최초 설정

### GitHub

| 위치 | 값 |
| --- | --- |
| Secrets | 없음. 앱 저장소가 공개라 checkout에, GHCR push에는 workflow 기본 토큰을 씀 |
| Variables | (선택) `VITE_API_BASE`, `VITE_MOCK_FEATURES` |
| Settings → Actions → General | "Require approval for all outside collaborators", Workflow permissions "Read and write permissions" |
| GHCR 패키지 공개 | 앱마다 첫 빌드 후 조직 Packages → `youthlink-<앱>` → Package settings → Change visibility → Public. 비공개로 두면 k3s가 이미지를 받지 못함 |

### EC2 (Amazon Linux 2023)

```bash
# k3s (EC2에서 이미지를 빌드하지 않으므로 Docker는 끈다)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable metrics-server
sudo systemctl disable --now docker 2>/dev/null || true
kubectl get nodes

# self-hosted 러너: 이 저장소 Settings → Actions → Runners → New self-hosted runner (Linux x64)
# 화면의 Download·Configure 명령을 ec2-user로 실행하고, 라벨을 물으면 k3s 입력
sudo ./svc.sh install && sudo ./svc.sh start

# 공통 리소스(namespace, ingress)는 deploy workflow(app: common)로 적용한 뒤 아래 Secret을 만든다
```

### Secret (값은 직접 입력, 파일·저장소에 남기지 않음)

```bash
kubectl -n youthlink create secret generic rag-secrets \
  --from-literal=OPENAI_API_KEY='...' \
  --from-literal=DATABASE_URL='postgresql+asyncpg://user:pass@<RDS_ENDPOINT>:5432/youthlink'

kubectl -n youthlink create secret generic etl-secrets \
  --from-literal=YOUTH_API_URL='...' \
  --from-literal=YOUTH_API_KEY='...' \
  --from-literal=OPENAI_API_KEY='...' \
  --from-literal=VWORLD_API_KEY='...' \
  --from-literal=VWORLD_API_DOMAIN='...' \
  --from-literal=DATABASE_URL='postgresql://user:pass@<RDS_ENDPOINT>:5432/youthlink'

kubectl -n youthlink create secret generic ragas-eval-secrets \
  --from-literal=OPENAI_API_KEY='...' \
  --from-literal=DATABASE_URL='postgresql://user:pass@<RDS_ENDPOINT>:5432/youthlink'
```

값을 바꿀 때는 `create secret ... --dry-run=client -o yaml | kubectl apply -f -`로 덮어쓰고 `kubectl -n youthlink rollout restart deploy/<앱>`을 실행합니다.

## 운영 명령 (EC2)

| 작업 | 명령 |
| --- | --- |
| 지역 마스터 최초 적재 | `kubectl apply -k k8s/load-regions/overlays/prod` |
| ETL 즉시 실행 | `kubectl -n youthlink create job etl-manual-$(date +%s) --from=cronjob/youthlink-etl` |
| 상태 | `kubectl -n youthlink get pods,jobs,cronjobs` |
| 로그 | `kubectl -n youthlink logs -f deploy/youthlink-rag`, `kubectl -n youthlink logs -f job/ragas-eval` |
| 동작 확인 | `curl -i http://<EIP>/` (프론트), `curl -i http://<EIP>/api/rooms` (RAG) |

## 로컬 검증

```bash
# 매니페스트 렌더링 확인 (클러스터 불필요)
for d in k8s/*/overlays/prod; do kubectl kustomize "$d" > /dev/null && echo "ok $d"; done
```
