FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install --legacy-peer-deps --ignore-scripts

COPY . .

ARG VITE_API_BASE_PATH
ENV VITE_API_BASE_PATH=${VITE_API_BASE_PATH}

RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/dist /var/www/frontend
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
