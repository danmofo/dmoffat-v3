FROM node:lts AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine AS runtime
COPY ./conf/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/certs /certs
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
EXPOSE 8443