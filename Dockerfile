FROM mcr.microsoft.com/powershell:6.2.2-ubuntu-16.04
LABEL maintainer="Matthew Kelly (Badgerati)"
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./src/ /usr/local/share/powershell/Modules/Pode