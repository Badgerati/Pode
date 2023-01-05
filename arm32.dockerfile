FROM mcr.microsoft.com/powershell:preview-7.3-arm32v7-ubuntu-18.04
LABEL maintainer="Matthew Kelly (Badgerati)"
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./pkg/ /usr/local/share/powershell/Modules/Pode