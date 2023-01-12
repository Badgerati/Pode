FROM badgerati/pode:test
COPY . /usr/src/app/
EXPOSE 8085
CMD [ "pwsh", "-c", "cd /usr/src/app; ./file-watchers.ps1" ]
