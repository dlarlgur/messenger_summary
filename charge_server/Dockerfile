FROM node:20-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 1024
ENV NODE_ENV=production PORT=1024
CMD ["node", "index.js"]
