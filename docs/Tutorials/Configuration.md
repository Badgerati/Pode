# Configuration

There is an *optional* configuration file that can work side-by-side with Pode. This file should be called `pode.json`, and must be placed in the same root directory as your main server script.

A lot of inbuilt configuration in Pode can be customised via the main server script, however there are times when it's easier to just use a configuration file - hence the optional existance of a `pode.json` file.

!!! note
    This file does not have to exist, unless you wish to use it.

## Structure

The file itself is just basic JSON, and has 4 main sections:

```json
{
    "server": { },
    "web": { },
    "smtp": { },
    "tcp": { }
}
```

Right now there is only one section that if of any use, and that is `web/static/defaults` for defining default static page (as [seen here](../Routes/Overview#default-pages)).