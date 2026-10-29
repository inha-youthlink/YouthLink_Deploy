#!/bin/sh
# ECR 로그인 토큰(12시간 유효)으로 youthlink 네임스페이스의 ecr-pull Secret을 갱신하는 스크립트 (EC2 호스트에서 root cron으로 6시간마다 실행)
#
# 전제: EC2에 AmazonEC2ContainerRegistryReadOnly 권한의 IAM Role이 붙어 있고 aws CLI가 설치되어 있다
# 등록: sudo crontab -e
#   0 */6 * * * AWS_REGION=ap-northeast-2 /opt/youthlink/ecr-refresh.sh >> /var/log/ecr-refresh.log 2>&1
set -eu

REGION="${AWS_REGION:-ap-northeast-2}"
NAMESPACE="youthlink"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
TOKEN="$(aws ecr get-login-password --region "$REGION")"

/usr/local/bin/kubectl -n "$NAMESPACE" create secret docker-registry ecr-pull \
  --docker-server="$REGISTRY" \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --dry-run=client -o yaml | /usr/local/bin/kubectl apply -f -

echo "$(date '+%F %T') ecr-pull refreshed for $REGISTRY"
