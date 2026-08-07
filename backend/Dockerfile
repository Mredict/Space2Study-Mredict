FROM node:18-alpine

WORKDIR /app

RUN chown -R node:node /app

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .
RUN ln -s /app/src/emails /app/emails ''' Bug fix for email templates path
USER node

EXPOSE 8080

CMD ["node", "src/app.js"]
