FROM microsoft/powershell:latest
LABEL maintainer="Matthew Kelly (Badgerati)"
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./src/ /usr/local/share/powershell/Modules/Pode
