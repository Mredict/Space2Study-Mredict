FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --legacy-peer-deps --ignore-scripts

COPY . .

RUN npm run build

FROM nginxinc/nginx-unprivileged:alpine

COPY --chown=101:101 --from=builder /app/dist /usr/share/nginx/html

COPY --chown=101:101 nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]