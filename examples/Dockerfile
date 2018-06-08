FROM badgerati/pode:latest
COPY . /usr/src/app/
EXPOSE 8085
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]