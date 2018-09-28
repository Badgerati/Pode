# Docker

Pode has a Docker container that you can use, by calling `docker pull badgerati/pode` you can pull down the latest image.

The image itself uses PowerShell Core on the Ubuntu Xenial OS.

## Dockerfile

An example of using the Pode container in your Dockerfile could be as follows:

!!! info
    The server script used below can be found in the `examples/web-pages-docker.ps1`

```dockerfile
# pull down the pode image
FROM badgerati/pode

# copy over the local files to the container
COPY . /usr/src/app/

# expose the port
EXPOSE 8085

# run the server
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]
```

## Build and Run

To build and run the above Dockerfile, you can use the following commands:

```bash
docker build -t pode/example .
docker run -p 8085:8085 -d pode/example
```

!!! info
    The Dockerfile above is the same Dockerfile in the `examples/` directory

Now try navigating to `localhost:8085` (or calling `curl localhost:8085`) and you should be greeted with a "Hello, world!" page.