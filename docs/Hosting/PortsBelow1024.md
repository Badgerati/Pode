# Using Ports Below 1024

#### Introduction

Traditionally in Linux, binding to ports below 1024 requires root privileges. This is a security measure, as these low-numbered ports are considered privileged. However, running applications as the root user poses significant security risks. This article explores methods to use these privileged ports with PowerShell (`pwsh`) in Linux, without running it as the root user.
There are different methods to achieve the goals.
Reverse Proxy is the right approach for a production environment, primarily if the server is connected directly to the internet.
The other solutions are reasonable after an in-depth risk analysis.

#### Using a Reverse Proxy

A reverse proxy like Nginx can listen on the privileged port and forward requests to your application running on an unprivileged port.

**Configuration:**

* Configure Nginx to listen on port 443 and forward requests to the port where your PowerShell script is listening.
* This method is widely used in web applications for its additional benefits like load balancing and SSL termination.

#### iptables Redirection

Using iptables, you can redirect traffic from a privileged port to a higher, unprivileged port.

**Implementation:**

* Set up an iptables rule to redirect traffic from, say, port 443 to a higher port where your PowerShell script is listening.
* `sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080`

**Benefits:**

* This approach doesn't require changing the privileges of the PowerShell executable or script.

#### Using `setcap` Command

The `setcap` utility can grant specific capabilities to an executable, like `pwsh`, enabling it to bind to privileged ports.

**How it Works:**

* Run `sudo setcap 'cap_net_bind_service=+ep' $(which pwsh)`. This command sets the `CAP_NET_BIND_SERVICE` capability on the PowerShell executable, allowing it to bind to any port below 1024.

**Security Consideration:**

* This method enhances security by avoiding running PowerShell as root, but it still grants significant privileges to the PowerShell process.

#### Utilizing Authbind

Authbind is a tool that allows a non-root user to bind to privileged ports.

**Setup:**

* Install Authbind, configure it to allow the desired port, and then start your PowerShell script using Authbind.
* For instance, `authbind --deep pwsh yourscript.ps1` allows the script to bind to a privileged port.

**Advantages:**

* It provides a finer-grained control over port access and doesn't require setting special capabilities on the PowerShell binary itself.
