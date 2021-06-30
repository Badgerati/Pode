# External

At most times you'll possibly be accessing your Pode server locally. However, you can access your server externally if you setup the endpoints appropriately using the [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) function. These will work on a your VMs, or in a Container.

!!! tip
    In each case, ensure any Firewalls or Network Security Groups are configured to allow access to the port.

## All Addresses

The default and common approach is to set your Pode server to listen on all IP addresses; this approach does require administrator privileges:

```powershell
Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
```

With this set, you can access your endpoint using the server's Public, Private IP address or VM name - plus the port number:

```powershell
Invoke-RestMethod -Uri 'http://<ip-address|vm-name>:8080'
```

## IP Address

The other way to expose your server externally is to create an endpoint using the server's Private/Public IP address; this approach does require administrator privileges. For example, assuming the the server's IP is `10.10.1.5`:

```powershell
Add-PodeEndpoint -Address 10.10.1.5 -Port 8080 -Protocol Http
```

With this set, you can access your endpoint using the server's Private IP address or VM name only - plus the port number:

```powershell
Invoke-RestMethod -Uri 'http://10.10.1.5:8080'
```

## Hostnames

Another way to expose your server externally is to allow only specific hostnames bound to the server's Private/Public IP address - something like SNI in IIS. This approach does require administrator privileges.

To do this, let's say you want to allow only `one.pode.com` and `two.pode.com` on a server with IP `10.10.1.5`. There are two way of doing this:

1. Specify the hostname/address directly on [`Add-PodeEndpoint`](../../../Functions/Core/Add-PodeEndpoint):

```powershell
Add-PodeEndpoint -Address 10.10.1.5 -Hostname 'one.pode.com' -Port 8080 -Protocol Http
Add-PodeEndpoint -Address 10.10.1.5 -Hostname 'two.pode.com' -Port 8080 -Protocol Http
```

2. Add the hostnames to the server's hosts file (or dns):

```plain
10.10.1.5   one.pode.com
10.10.1.5   two.pode.com
```

Then, create the endpoints within your server using the `-LookupHostname` switch:

```powershell
Add-PodeEndpoint -Hostname 'one.pode.com' -Port 8080 -Protocol Http -LookupHostname
Add-PodeEndpoint -Hostname 'two.pode.com' -Port 8080 -Protocol Http -LookupHostname
```

Next, make sure to add the hostnames into your hosts file, or into DNS.

With these set, you can access your endpoint using only the `one.pode.com` and `two.pode.com` hostnames - plus the port number:

```powershell
Invoke-RestMethod -Uri 'http://one.pode.com:8080'
Invoke-RestMethod -Uri 'http://two.pode.com:8080'
```

## Netsh

This next way allows you to access your server external, but be able to run the server without administrator privileges. The initial setup does require administrator privileges, but running the server does not.

To do this, let's say you want to access your server on `10.10.1.5`, you can use the following steps:

1. You server should be listening on localhost and then any port you wish:

```powershell
Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http
```

2. Next, you can run the following command as an administrator where the `<external-port>` can be any port that's not the port in your [`Add-PodeEndpoint`](../../../Functions/Core/Add-PodeEndpoint) (such as port+1):

```bash
netsh interface portproxy add v4tov4 listenport=<external-port> connectaddress=127.0.0.1 connectport=<pode-port>
```

For example, the above endpoint could be:

```bash
netsh interface portproxy add v4tov4 listenport=8081 connectaddress=127.0.0.1 connectport=8080
```

3. Run your Pode server as a non-admin user.

With this done, you can access your endpoint on `10.10.1.5:8081`:

```powershell
Invoke-RestMethod -Uri 'http://10.10.1.5:8081'
```

This works by having `netsh interface portproxy` redirect traffic to the local port which your Pode server is listening on.
