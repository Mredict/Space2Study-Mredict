FROM node:18-alpine3.20 AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --legacy-peer-deps --ignore-scripts

COPY . .

ARG VITE_API_BASE_PATH=/api/

ENV VITE_API_BASE_PATH=$VITE_API_BASE_PATH

RUN npm run build

FROM nginxinc/nginx-unprivileged:alpine3.20

COPY --chmod=555 --from=builder /app/dist /usr/share/nginx/html
COPY --chmod=555 nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
USER 101


CMD ["nginx", "-g", "daemon off;"]