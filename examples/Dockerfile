FROM badgerati/pode:latest
COPY . /usr/src/app/
EXPOSE 10000
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]