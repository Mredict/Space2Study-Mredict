FROM node:18-alpine

RUN apk update && apk upgrade --no-cache

RUN mkdir -p /app && chown -R node:node /app

WORKDIR /app

USER node

COPY --chown=node:node package*.json ./

RUN npm ci --legacy-peer-deps

COPY --chown=node:node . .

# Email path fix
RUN ln -s /app/src/emails /app/emails

EXPOSE 8080

CMD ["node", "src/app.js"]
