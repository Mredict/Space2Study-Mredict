FROM node:18

WORKDIR /app

COPY package*.json ./

RUN npm install --legacy-peer-deps

COPY . .

RUN ln -s /app/src/emails /app/emails

EXPOSE 8080

CMD ["node", "src/app.js"]