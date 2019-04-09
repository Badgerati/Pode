# CSRF

Pode has inbuilt support for CSRF middleware and tokens on web requests and responses, where the secret can be stored in either sessions or signed cookies. When configured, the middleware will check for, and validate, a CSRF token the web requests for valid routes - with support to ignore specific HTTP methods. If a route fails CSRF validation, then Pode will return a 403 status code.

## Usage

To setup and configure using CSRF in Pode, you can use the [`csrf`](../../../Functions/Middleware/Csrf) function. This function allows you to generate CSRF tokens, as well as two methods of returning valid middleware that can be supplied to the [`middleware`](../../../Functions/Core/Middleware) function - or be used on `routes`.

The make-up of the `csrf` function is as follows:

```powershell
csrf <action> [-ignoreMethods @()] [-secret <string>] [-cookie]

# or with aliases:
csrf <action> [-i @()] [-s <string>] [-c]
```

### Middleware

### Check & Setup

### Tokens

The [`csrf`](../../../Functions/Middleware/Csrf) function allows you to generate tokens using the `token` action. It will randomly generate a token that you use in your webpages, such as in hidden form inputs or meta elements for AJAX requests.

## Example
