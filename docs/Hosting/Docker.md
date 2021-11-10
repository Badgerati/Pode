# Docker

Pode has a Docker image that you can use to host your server, for instructions on pulling these images you can [look here](../../Installation).

The images use PowerShell v7.1.5 on either an Ubuntu Bionic (default), Alpine, or ARM32 image.

## Images

!!! info
    The server script used below can be found in the [`examples/web-pages-docker.ps1`](https://github.com/Badgerati/Pode/blob/develop/examples/web-pages-docker.ps1) directory in the repo.

### Default

The default Pode image is an Ubuntu Bionic image with PowerShell v7.1.5 and Pode installed. An example of using this image in your Dockerfile could be as follows:

```dockerfile
# pull down the pode image
FROM badgerati/pode:latest

# or use the following for GitHub
# FROM docker.pkg.github.com/badgerati/pode/pode:latest

# copy over the local files to the container
COPY . /usr/src/app/

# expose the port
EXPOSE 8085

# run the server
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]
```

### Alpine

Pode also has an image for Alpine, an example of using this image in your Dockerfile could be as follows:

```dockerfile
# pull down the pode image
FROM badgerati/pode:latest-alpine

# or use the following for GitHub
# FROM docker.pkg.github.com/badgerati/pode/pode:latest-alpine

# copy over the local files to the container
COPY . /usr/src/app/

# expose the port
EXPOSE 8085

# run the server
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]
```

### ARM32

Pode also has an image for ARM32, meaning you can run Pode on Raspberry Pis. An example of using this image in your Dockerfile could be as follows:

```dockerfile
# pull down the pode image
FROM badgerati/pode:latest-arm32

# or use the following for GitHub
# FROM docker.pkg.github.com/badgerati/pode/pode:latest-arm32

# copy over the local files to the container
COPY . /usr/src/app/

# expose the port
EXPOSE 8085

# run the server
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]
```

## Build and Run

To build and run the above Dockerfiles, you can use the following commands:

```bash
docker build -t pode/example .
docker run -p 8085:8085 -d pode/example
```

Now try navigating to `http://localhost:8085` (or calling `curl http://localhost:8085`) and you should be greeted with a "Hello, world!" page.

!!! warning
    The ARM32 images will likely only work on Raspberry Pis, or an Operating System that supports ARM.
