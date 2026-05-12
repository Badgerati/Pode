FROM mcr.microsoft.com/dotnet/sdk:10.0-resolute-arm32v7
LABEL maintainer="Matthew Kelly (Badgerati)"
ENV POWERSHELL_TELEMETRY_OPTOUT=1
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./pkg/ /usr/local/share/powershell/Modules/Pode