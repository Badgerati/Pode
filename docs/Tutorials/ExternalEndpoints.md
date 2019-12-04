# External Endpoints

At most times you'll possibly be accessing your Pode server locally. However, you can access your server externally if you setup the endpoints appropriately using the [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) function. These will work on a your VMs, or in a Container.

!!! tip
    In each case, ensure any Firewalls or Network Security Groups are configured to allow access to the port.

## All Addresses

The default and common approach is to set your Pode server to listen on all IP addresses:

```powershell
Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
```

With this set, you can access your endpoint using the server's Public, Private IP address or VM name - plus the port number:

```powershell
Invoke-RestMethod -Uri 'http://<ip-address|vm-name>:8080'
```

## IP Address

The other way to expose your server externally is to create an endpoint using the server's Private/Public IP address. For example, assuming the the server's IP is `10.10.1.5`:

```powershell
Add-PodeEndpoint -Address 10.10.1.5 -Port 8080 -Protocol Http
```

With this set, you can access your endpoint using the server's Private IP address or VM name only - plus the port number:

```powershell
Invoke-RestMethod -Uri 'http://10.10.1.5:8080'
```

## Hostnames

The final way to expose your server externally is to allow only specific hostnames bound to the server's Private/Public IP address - something like SNI in IIS.

To do this, let's say you want to allow only `one.pode.com` and `two.pode.com` on a server with IP `10.10.1.5`. The first thing to do is add the hostnames to the server's hosts file (or dns):

```plain
10.10.1.5   one.pode.com
10.10.1.5   two.pode.com
```

Then, create the endpoints within your server:

```powershell
Add-PodeEndpoint -Address 'one.pode.com' -Port 8080 -Protocol Http
Add-PodeEndpoint -Address 'two.pode.com' -Port 8080 -Protocol Http
```

Next, make sure to add the hostnames into your hosts file, or into DNS.

With these set, you can access your endpoint using only the `one.pode.com` and `two.pode.com` hostnames - plus the port number:

```powershell
Invoke-RestMethod -Uri 'http://one.pode.com:8080'
Invoke-RestMethod -Uri 'http://two.pode.com:8080'
```
