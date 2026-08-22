FROM node:18-alpine3.20 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npm prune --production

FROM node:18-alpine3.20 AS runner

ENV NODE_ENV=production
WORKDIR /app

RUN apk update && apk upgrade --no-cache

COPY --chmod=555 --from=builder /app/node_modules ./node_modules
COPY --chmod=555 --from=builder /app/package*.json ./
COPY --chmod=555 --from=builder /app/ ./

# Application symlink Fix
RUN ln -s /app/src/emails /app/emails

USER 1000:1000

EXPOSE 8080

CMD ["node", "src/app.js"]

