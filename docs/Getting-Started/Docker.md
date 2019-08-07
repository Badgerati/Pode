# Docker

Pode has a Docker image that you can use, for instructions on pulling these images you can [look here](../Installation).

The images use PowerShell Core on either an Ubuntu Xenial (default) or ARM32 image.

## Images

!!! info
    The server script used below can be found in the [`examples/web-pages-docker.ps1`](https://github.com/Badgerati/Pode/blob/develop/examples/web-pages-docker.ps1) directory in the repo.

### Default

The default Pode image is an Ubuntu Xenial image with PowerShell Core and Pode installed. An example of using this image in your Dockerfile could be as follows:

```dockerfile
# pull down the pode image
FROM badgerati/pode:latest

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