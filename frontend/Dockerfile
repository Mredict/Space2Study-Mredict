FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --legacy-peer-deps --ignore-scripts

COPY . .

RUN npm run build

FROM nginxinc/nginx-unprivileged:alpine

COPY --chmod=555 --from=builder /app/dist /usr/share/nginx/html
COPY --chmod=555 nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
USER 101


CMD ["nginx", "-g", "daemon off;"]