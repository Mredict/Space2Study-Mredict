FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps --ignore-scripts

COPY . .
RUN npm prune --production

FROM node:18-alpine AS runner

ENV NODE_ENV=production
WORKDIR /app

RUN apk update && apk upgrade --no-cache

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/src ./src

# Application symlink Fix
RUN ln -s /app/src/emails /app/emails

RUN chmod -R 555 /app

USER node

EXPOSE 8080

CMD ["node", "src/app.js"]

