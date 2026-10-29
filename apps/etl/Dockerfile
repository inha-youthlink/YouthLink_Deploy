# youthlink-data-pipeline ETL 스크립트를 실행하는 이미지 (명령은 CronJob에서 지정)
# 빌드: docker build -f apps/etl/Dockerfile -t youthlink/etl <youthlink-data-pipeline 경로>
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY etl/ etl/

# load_policies.py가 실패 레코드를 etl/logs/에 쓰므로 쓰기 권한을 준다
RUN useradd --system --uid 10001 --no-create-home etl \
    && mkdir -p etl/logs \
    && chown etl:etl etl/logs
USER 10001

# 비밀값(YOUTH_API_KEY, OPENAI_API_KEY, DATABASE_URL 등)은 Secret으로 주입한다
CMD ["python", "etl/load_policies.py", "--help"]
