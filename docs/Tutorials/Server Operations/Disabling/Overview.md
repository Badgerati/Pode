# Overview

Pode provides a way to control the availability of the server for new incoming requests. Using the **Disable** and **Enable** operations, you can temporarily block or allow client requests while maintaining the server's state. These features are particularly useful for maintenance, load management, or during planned downtime.

---

## Disabling the Server

The **Disable** operation blocks new incoming requests to the Pode server by integrating middleware that returns a `503 Service Unavailable` response to clients. This is ideal for situations where you need to prevent access temporarily without fully stopping the server.

### How It Works

1. **Blocking Requests**:
      - All new incoming requests are intercepted and responded to with a `503 Service Unavailable` status.
      - A `Retry-After` header is included in the response, advising clients when they can attempt to reconnect.

2. **Customizing Retry Time**:
      - The retry time (in seconds) can be customized to specify when the service is expected to become available again. By default, this is set to **1 hour**.

### Example Usage

```powershell
# Block new requests with the default retry time (1 hour)
Disable-PodeServer

# Block new requests with a custom retry time (5 minutes)
Disable-PodeServer -RetryAfter 300
```

---

## Enabling the Server

The **Enable** operation restores the Pode server's ability to accept new incoming requests by removing the middleware that blocks them. This is useful after completing maintenance or resolving an issue.

### How It Works

1. **Resetting the Cancellation Token**:
   - The server's internal state is updated to resume normal operations, allowing new incoming requests to be processed.

2. **Restoring Functionality**:
   - Once enabled, the Pode server can handle requests as usual, with no further interruptions.

### Example Usage

```powershell
# Enable the Pode server to resume accepting requests
Enable-PodeServer
```

---

## When to Use Disable and Enable

These operations are particularly useful for:

- **Planned Downtime**: Prevent client access during scheduled maintenance or updates.
- **Load Management**: Temporarily block requests during high traffic to alleviate pressure on the server.
- **Testing**: Control the server's availability during development or troubleshooting scenarios.
