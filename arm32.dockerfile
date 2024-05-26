FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04-arm32
LABEL maintainer="Matthew Kelly (Badgerati)"
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./pkg/ /usr/local/share/powershell/Modules/Pode