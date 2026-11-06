# YouthLink_Front(Vite SPA)를 빌드해 nginx로 서빙하는 이미지
# 빌드: nginx.conf는 이 폴더에 있으므로 --build-context로 넘긴다
#   docker build -f apps/front/Dockerfile --build-context conf=apps/front -t youthlink/front <YouthLink_Front 경로>
FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
# Vite는 VITE_* 값을 빌드할 때 JS에 고정한다. 빈 값이면 /api(같은 출처)로 호출한다
# VITE_MOCK_FEATURES는 넘기지 않아 mock(MSW)은 항상 꺼진다
ARG VITE_API_BASE=""
ENV VITE_API_BASE=$VITE_API_BASE
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY --from=conf nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 8080
