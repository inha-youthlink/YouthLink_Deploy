# YouthLink_RAG(FastAPI)를 uvicorn으로 띄우는 이미지
# 빌드: docker build -f apps/rag/Dockerfile -t youthlink/rag <YouthLink_RAG 경로>
FROM python:3.12-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:0.9.5 /uv /bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY app/ app/

RUN useradd --system --uid 10001 --no-create-home rag
USER 10001

EXPOSE 8000

# 비밀값(OPENAI_API_KEY, DATABASE_URL)은 이미지에 넣지 않고 Secret으로 주입한다
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
