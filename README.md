# YouthLink_Deploy

YouthLink는 모듈마다 저장소와 실행 방식이 다릅니다. 배포 파일(Dockerfile, k8s 매니페스트, 설정, CI)을 각 저장소에 두면 같은 일을 네 곳에서 따로 관리하게 되고, 배포 시점과 이력도 흩어집니다. 그래서 앱 저장소는 소스코드만 관리하고, 배포는 이 저장소 하나에서 합니다.

| 모듈 | 저장소 | 실행 방식 |
| --- | --- | --- |
| RAG (FastAPI) | `YouthLink_RAG` | 상시 실행 (Deployment) |
| 프론트 (React) | `YouthLink_Front` | 상시 실행 (Deployment, nginx) |
| ETL (정책 적재·임베딩) | `youthlink-data-pipeline` | 매일 배치 (CronJob) |
| 평가 (RAGAS) | `rag_ragas_evaluation` | 필요할 때 1회 (Job) |

이 저장소는 모듈별 공통 변수 설정과 배포 이미지를 관리하고, 4개 앱을 EC2 단일 노드 k3s에 배포합니다.

구성, 설치 순서, 결정 이유는 `docs/배포계획.md`를 참고합니다.

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

## 로컬 검증

```bash
# 매니페스트 렌더링 확인 (클러스터 불필요)
for d in k8s/*/overlays/prod; do kubectl kustomize "$d" > /dev/null && echo "ok $d"; done
```
