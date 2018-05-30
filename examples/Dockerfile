FROM badgerati/pode:latest

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . .

EXPOSE 8085

CMD [ "pwsh", "-c", "./web-pages-docker.ps1" ]