FROM node:20-alpine
WORKDIR /app

# Копируем package.json именно из tgback-improved, а не root
COPY tgback-improved/package.json ./

RUN npm install

# Копируем только исходники tgback-improved
COPY tgback-improved/ .

RUN npm run build

EXPOSE 3000
CMD ["npm", "start"]
