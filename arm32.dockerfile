FROM mcr.microsoft.com/powershell:7.1.5-arm32v7-ubuntu-18.04-20211021
LABEL maintainer="Matthew Kelly (Badgerati)"
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./pkg/ /usr/local/share/powershell/Modules/Pode