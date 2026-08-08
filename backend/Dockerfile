FROM node:18-alpine

WORKDIR /app

RUN chown -R node:node /app

USER node

COPY --chown=node:node package*.json ./

RUN npm ci --legacy-peer-deps

COPY --chown=node:node . .

# Email path fix
RUN ln -s /app/src/emails /app/emails

EXPOSE 8080

CMD ["node", "src/app.js"]
