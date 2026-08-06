FROM node:18 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y xdg-utils

COPY package*.json ./
RUN npm install --ignore-scripts --production

COPY . .

RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/dist /var/www/frontend

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]