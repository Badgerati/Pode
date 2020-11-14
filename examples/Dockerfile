FROM badgerati/pode:test
COPY . /usr/src/app/
EXPOSE 10000
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]