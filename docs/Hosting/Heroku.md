# Heroku

Using Pode's docker image, you can host your Pode server in Heroku.

Hosting your server in Heroku works in a similar fashion to IIS, in that Pode can detect when you're using Heroku and set the Address/Port appropriately. Furthermore, Heroku can deal with HTTPS for you, so your Pode server only needs to bind onto HTTP within the container.

## Requirements

To get started you'll need the following software installed:

* Git
* Docker
* Heroku CLI

You'll also need an account with [Heroku](https://heroku.com/).

## Server

Your server will need a Dockerfile, such as the following:

```dockerfile
FROM badgerati/pode:latest
COPY . /usr/src/app/
EXPOSE $PORT
CMD [ "pwsh", "-c", "cd /usr/src/app; ./server.ps1" ]
```

While Pode can detect that your server is running in Heroku, and can set your server's endpoints appropriately, the Dockerfile will need to use the `$PORT` variable that Heroku set.

You can set this when testing locally as follows (assuming your server is listening on port 5000 locally):

```powershell
docker run -p 5000:5000 -e PORT=5000 <image-name>
```

The server script itself could look as follows:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address 127.0.0.1 -Port 5000 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Response = 'Hello, world!' }
    }
}
```

Here we have an endpoint on localhost and port 5000; but when in Heroku Pode will automatically change the address/port for you.

## Build and Push

First, login to Heroku and then its Container Registry:

```powershell
heroku login
heroku container:login
```

Next, create an app - note that you'll need to get the app-name that is returned:

```powershell
heroku create
$appName = '<app-name-from-above>'
```

Then, push and release your server to the created app:

```powershell
heroku container:push web --app $appName
heroku container:release web --app $appName
```

Finally, you can open your server as follows:

```powershell
heroku open --app $appName
```

After this, you can view the logs of the server using:

```powershell
heroku logs --tail --app $appName
```

## Useful Links

* [Building Docker Images with heroku.yml \| Heroku Dev Center](https://devcenter.heroku.com/articles/build-docker-images-heroku-yml)
* [Container Registry & Runtime (Docker Deploys) \| Heroku Dev Center](https://devcenter.heroku.com/articles/container-registry-and-runtime)
