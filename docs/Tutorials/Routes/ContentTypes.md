# Content Types

Any payload supplied in a web request is normally parsed using the content type on the request's headers. However, it's possible to override - or 'force' - a specific content type on routes when parsing the payload. This can be achieved by either using the `-ContentType` parameter on the `route` function, or using the `pode.json` configuration file.

## Routes

You can specify a specific content type to use per route by using the `-ContentType` parameter.

## Config

Using the `pode.json` configuration file, you can define a default content type to use for every route. You can also define patterns to match multiple route paths.

## Precedence

The content type that will be used is determined by the following order:

1. Being defined on the `route` function
2. The route matches a pattern defined in the configuration file
3. A default content type is defined in the configuration file
4. The content type supplied on the web request