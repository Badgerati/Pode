
# CORS

## What is CORS?
Cross-Origin Resource Sharing (CORS) is a security feature implemented by web browsers to restrict web pages from making requests to a different domain than the one that served the web page. This is a critical aspect of web security, helping to prevent malicious sites from accessing sensitive data from another domain.

## CORS Challenges
When developing web applications, you may encounter situations where your web page needs to request resources from a different domain. This can lead to CORS errors if the appropriate headers are not set to allow these cross-origin requests. Common challenges include:
- Handling pre-flight requests.
- Allowing specific methods and headers.
- Managing credentials in cross-origin requests.
- Setting the appropriate origins.

## Addressing CORS Challenges

Pode simplifies handling CORS by providing the `Set-PodeSecurityAccessControl` function, which allows you to define the necessary headers to manage cross-origin requests effectively.

### Key Headers for CORS

1. **Access-Control-Allow-Origin**: Specifies which origins are permitted to access the resource.
2. **Access-Control-Allow-Methods**: Lists the HTTP methods that are allowed when accessing the resource.
3. **Access-Control-Allow-Headers**: Indicates which HTTP headers can be used during the actual request.
4. **Access-Control-Max-Age**: Specifies how long the results of a pre-flight request can be cached.
5. **Access-Control-Allow-Credentials**: Indicates whether credentials are allowed in the request.

### Setting CORS Headers instead

The `Set-PodeSecurityAccessControl` function allows you to set these headers easily. Here’s how you can address common CORS challenges using this function:

1. **Allowing All Origins**
   ```powershell
   Set-PodeSecurityAccessControl -Origin '*'
   ```
   This sets the `Access-Control-Allow-Origin` header to allow requests from any origin.

2. **Specifying Allowed Methods**
   ```powershell
   Set-PodeSecurityAccessControl -Methods 'GET', 'POST', 'OPTIONS'
   ```
   This sets the `Access-Control-Allow-Methods` header to allow only the specified methods.

3. **Specifying Allowed Headers**
   ```powershell
   Set-PodeSecurityAccessControl -Headers 'Content-Type', 'Authorization'
   ```
   This sets the `Access-Control-Allow-Headers` header to allow the specified headers.

4. **Handling Credentials**
   ```powershell
   Set-PodeSecurityAccessControl -Credentials
   ```
   This sets the `Access-Control-Allow-Credentials` header to allow credentials in requests.

5. **Setting Cache Duration for Pre-flight Requests**
   ```powershell
   Set-PodeSecurityAccessControl -Duration 3600
   ```
   This sets the `Access-Control-Max-Age` header to cache the pre-flight request for one hour.

6. **Automatic Header and Method Detection**
   ```powershell
   Set-PodeSecurityAccessControl -AutoHeaders -AutoMethods
   ```
   These parameters automatically populate the list of allowed headers and methods based on your OpenApi definition and defined routes, respectively.

7. **Enabling Global OPTIONS Route**
   ```powershell
   Set-PodeSecurityAccessControl -WithOptions
   ```
   This creates a global OPTIONS route to handle pre-flight requests automatically.

8. **Additional Security with Cross-Domain XHR Requests**
   ```powershell
   Set-PodeSecurityAccessControl -CrossDomainXhrRequests
   ```
   This adds the 'x-requested-with' header to the list of allowed headers, enhancing security.

### Example Configuration

Here is an example of configuring CORS settings in Pode using `Set-PodeSecurityAccessControl`:

```powershell
Set-PodeSecurityAccessControl -Origin 'https://example.com' -Methods 'GET', 'POST' -Headers 'Content-Type', 'Authorization' -Duration 7200 -Credentials -WithOptions -AutoHeaders -AutoMethods -CrossDomainXhrRequests
```

This example sets up CORS to allow requests from `https://example.com`, allows `GET` and `POST` methods, permits `Content-Type` and `Authorization` headers, enables credentials, caches pre-flight requests for two hours, automatically detects headers and methods, and allows cross-domain XHR requests.

### More Information on CORS

For more information on CORS, you can refer to the following resources:
- [Fetch Living Standard](https://fetch.spec.whatwg.org/)
- [CORS in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/cors?view=aspnetcore-7.0#credentials-in-cross-origin-requests)
- [MDN Web Docs on CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
