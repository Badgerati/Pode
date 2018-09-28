# Logging to Terminal

## Setup

This tutorial will be short and sweet! To start logging requests to your server onto the terminal, you simply do the following:

```powershell
Server {
    listen *:8080 http

    # just this line!
    logger terminal
}
```

And that's it, done!