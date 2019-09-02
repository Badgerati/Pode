FROM badgerati/ps-core:6.2.2-arm32
LABEL maintainer="Matthew Kelly (Badgerati)"
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./src/ /usr/local/share/powershell/Modules/Pode