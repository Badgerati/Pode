# OpenAPI Specification and Pode

#### OpenAPI Version 3.0.3 and Pode 2.10.0

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [BCP 14](https://tools.ietf.org/html/bcp14) [RFC2119](https://tools.ietf.org/html/rfc2119) [RFC8174](https://tools.ietf.org/html/rfc8174) when, and only when, they appear in all capitals, as shown here.

This document is licensed under [The Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0.html).

## Introduction

The OpenAPI Specification (OAS) defines a standard, language-agnostic interface to RESTful APIs which allows both humans and computers to discover and understand the capabilities of the service without access to source code, documentation, or through network traffic inspection. When properly defined, a consumer can understand and interact with the remote service with a minimal amount of implementation logic.

An OpenAPI definition can then be used by documentation generation tools to display the API, code generation tools to generate servers and clients in various programming languages, testing tools, and many other use cases.


## Table of Contents
<!-- TOC depthFrom:1 depthTo:3 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Definitions](#definitions)
	- [OpenAPI Document](#oasDocument)
	- [Path Templating](#pathTemplating)
	- [Media Types](#mediaTypes)
	- [HTTP Status Codes](#httpCodes)
- [Specification](#specification)
	- [Versions](#versions)
	- [Format](#format)
	- [Document Structure](#documentStructure)
	- [Data Types](#dataTypes)
	- [Rich Text Formatting](#richText)
	- [Relative References In URLs](#relativeReferences)
	- [Schema](#schema)
		- [OpenAPI Object](#oasObject)
		- [Info Object](#infoObject)
		- [Contact Object](#contactObject)
		- [License Object](#licenseObject)
		- [Server Object](#serverObject)
		- [Server Variable Object](#serverVariableObject)
		- [Components Object](#componentsObject)
		- [Paths Object](#pathsObject)
		- [Path Item Object](#pathItemObject)
		- [Operation Object](#operationObject)
		- [External Documentation Object](#externalDocumentationObject)
		- [Parameter Object](#parameterObject)
		- [Request Body Object](#requestBodyObject)
		- [Media Type Object](#mediaTypeObject)
		- [Encoding Object](#encodingObject)
		- [Responses Object](#responsesObject)
		- [Response Object](#responseObject)
		- [Callback Object](#callbackObject)
		- [Example Object](#exampleObject)
		- [Link Object](#linkObject)
		- [Header Object](#headerObject)
		- [Tag Object](#tagObject)
		- [Reference Object](#referenceObject)
		- [Schema Object](#schemaObject)
		- [Discriminator Object](#discriminatorObject)
		- [XML Object](#xmlObject)
		- [Security Scheme Object](#securitySchemeObject)
		- [OAuth Flows Object](#oauthFlowsObject)
		- [OAuth Flow Object](#oauthFlowObject)
		- [Security Requirement Object](#securityRequirementObject)
	- [Specification Extensions](#specificationExtensions)
	- [Security Filtering](#securityFiltering)
- [Appendix A: Revision History](#revisionHistory)


<!-- /TOC -->

## Definitions

##### <a name="oasDocument"></a>OpenAPI Document
A document (or set of documents) that defines or describes an API. An OpenAPI definition uses and conforms to the OpenAPI Specification.

##### <a name="pathTemplating"></a>Path Templating
Path templating refers to the usage of template expressions, delimited by curly braces ({}), to mark a section of a URL path as replaceable using path parameters.

Each template expression in the path MUST correspond to a path parameter that is included in the [Path Item](#path-item-object) itself and/or in each of the Path Item's [Operations](#operation-object).

##### <a name="mediaTypes"></a>Media Types
Media type definitions are spread across several resources.
The media type definitions SHOULD be in compliance with [RFC6838](https://tools.ietf.org/html/rfc6838).

Some examples of possible media type definitions:
```
  text/plain; charset=utf-8
  application/json
  application/vnd.github+json
  application/vnd.github.v3+json
  application/vnd.github.v3.raw+json
  application/vnd.github.v3.text+json
  application/vnd.github.v3.html+json
  application/vnd.github.v3.full+json
  application/vnd.github.v3.diff
  application/vnd.github.v3.patch
```
##### <a name="httpCodes"></a>HTTP Status Codes
The HTTP Status Codes are used to indicate the status of the executed operation.
The available status codes are defined by [RFC7231](https://tools.ietf.org/html/rfc7231#section-6) and registered status codes are listed in the [IANA Status Code Registry](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml).

## OpenApi Features Unsupported by Pode

 - Relative Schema Document Example

## Specification

### Versions

The OpenAPI Specification is versioned using [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) (semver) and follows the semver specification.

The `major`.`minor` portion of the semver (for example `3.0`) SHALL designate the OAS feature set. Typically, *`.patch`* versions address errors in this document, not the feature set. Tooling which supports OAS 3.0 SHOULD be compatible with all OAS 3.0.\* versions. The patch version SHOULD NOT be considered by tooling, making no distinction between `3.0.0` and `3.0.1` for example.

Each new minor version of the OpenAPI Specification SHALL allow any OpenAPI document that is valid against any previous minor version of the Specification, within the same major version, to be updated to the new Specification version with equivalent semantics. Such an update MUST only require changing the `openapi` property to the new minor version.

For example, a valid OpenAPI 3.0.2 document, upon changing its `openapi` property to `3.1.0`, SHALL be a valid OpenAPI 3.1.0 document, semantically equivalent to the original OpenAPI 3.0.2 document. New minor versions of the OpenAPI Specification MUST be written to ensure this form of backward compatibility.

An OpenAPI document compatible with OAS 3.\*.\* contains a required [`openapi`](#oasVersion) field which designates the semantic version of the OAS that it uses. (OAS 2.0 documents contain a top-level version field named [`swagger`](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#swaggerObject) and value `"2.0"`.)

### Format

An OpenAPI document that conforms to the OpenAPI Specification is itself a JSON object, which may be represented either in JSON or YAML format.

For example, if a field has an array value, the JSON array representation will be used:

```json
{
   "field": [ 1, 2, 3 ]
}
```
All field names in the specification are **case sensitive**.
This includes all fields that are used as keys in a map, except where explicitly noted that keys are **case insensitive**.

The schema exposes two types of fields: Fixed fields, which have a declared name, and Patterned fields, which declare a regex pattern for the field name.

Patterned fields MUST have unique names within the containing object.

In order to preserve the ability to round-trip between YAML and JSON formats, YAML version [1.2](https://yaml.org/spec/1.2/spec.html) is RECOMMENDED along with some additional constraints:

- Tags MUST be limited to those allowed by the [JSON Schema ruleset](https://yaml.org/spec/1.2/spec.html#id2803231).
- Keys used in YAML maps MUST be limited to a scalar string, as defined by the [YAML Failsafe schema ruleset](https://yaml.org/spec/1.2/spec.html#id2802346).

**Note:** While APIs may be defined by OpenAPI documents in either YAML or JSON format, the API request and response bodies and other content are not required to be JSON or YAML.

### <a name="documentStructure"></a>Document Structure

An OpenAPI document MAY be made up of a single document or be divided into multiple, connected parts at the discretion of the user. In the latter case, `$ref` fields MUST be used in the specification to reference those parts as follows from the [JSON Schema](https://json-schema.org) definitions.

It is RECOMMENDED that the root OpenAPI document be named: `openapi.json` or `openapi.yaml`.

### <a name="dataTypes"></a>Data Types

Primitive data types in the OAS are based on the types supported by the [JSON Schema Specification Wright Draft 00](https://tools.ietf.org/html/draft-wright-json-schema-00#section-4.2).
Note that `integer` as a type is also supported and is defined as a JSON number without a fraction or exponent part.
`null` is not supported as a type (see [`nullable`](#schemaNullable) for an alternative solution).
Models are defined using the [Schema Object](#schemaObject), which is an extended subset of JSON Schema Specification Wright Draft 00.

<a name="dataTypeFormat"></a>Primitives have an optional modifier property: `format`.
OAS uses several known formats to define in fine detail the data type being used.
However, to support documentation needs, the `format` property is an open `string`-valued property, and can have any value.
Formats such as `"email"`, `"uuid"`, and so on, MAY be used even though undefined by this specification.
Types that are not accompanied by a `format` property follow the type definition in the JSON Schema. Tools that do not recognize a specific `format` MAY default back to the `type` alone, as if the `format` is not specified.

The formats defined by the OAS are:

| [`type`](#dataTypes) | [`format`](#dataTypeFormat) | [`Pode CmdLet`](https://badgerati.github.io/Pode/Tutorials/OpenAPI/)                                                                      | Comments                                                                                         |
| -------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `integer`            | `int32`                     | [`New-PodeOAIntProperty -Name 'anInteger' -Format Int32`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAIntProperty)       | signed 32 bits                                                                                   |
| `integer`            | `int64`                     | [`New-PodeOAIntProperty -Name 'aLong' -Format Int64`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAIntProperty)           | signed 64 bits (a.k.a long)                                                                      |
| `number`             | `float`                     | [`New-PodeOANumberProperty -Name 'aFloat' -Format Float`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOANumberProperty)    |
| `number`             | `double`                    | [`New-PodeOANumberProperty -Name 'aDouble' -Format Double`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOANumberProperty)  |
| `string`             |                             | [`New-PodeOAStringProperty -Name 'aString'`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAStringProperty)                 |
| `string`             | `byte`                      | [`New-PodeOAStringProperty -Name 'aString' -Format Byte`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAStringProperty)    | base64 encoded characters                                                                        |
| `string`             | `binary`                    | [`New-PodeOAStringProperty -Name 'aString' -Format Binary`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAStringProperty)  | any sequence of octets                                                                           |
| `boolean`            |                             | [`New-PodeOABoolProperty  -Name 'aBoolean'`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOABoolProperty)                   |
| `string`             | `date`                      | [`New-PodeOAStringProperty -Name 'aDate' -Format Date`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAStringProperty)      | As defined by `full-date` - [RFC3339](https://datatracker.ietf.org/doc/html/rfc3339#section-5.6) |
| `string`             | `date-time`                 | [`New-PodeOAStringProperty -Name 'aDate' -Format Date-Time`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAStringProperty) | As defined by `date-time` - [RFC3339](https://datatracker.ietf.org/doc/html/rfc3339#section-5.6) |
| `string`             | `password`                  | [`New-PodeOAStringProperty -Name 'aDate' -Format Password`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAStringProperty)  | A hint to UIs to obscure input.                                                                  |


### <a name="richText"></a>Rich Text Formatting
Throughout the specification `description` fields are noted as supporting CommonMark markdown formatting.
Where OpenAPI tooling renders rich text it MUST support, at a minimum, markdown syntax as described by [CommonMark 0.27](https://spec.commonmark.org/0.27/). Tooling MAY choose to ignore some CommonMark features to address security concerns.

### <a name="relativeReferences"></a>Relative References in URLs

Unless specified otherwise, all properties that are URLs MAY be relative references as defined by [RFC3986](https://tools.ietf.org/html/rfc3986#section-4.2).
Relative references are resolved using the URLs defined in the [`Server Object`](#serverObject) as a Base URI.

Relative references used in `$ref` are processed as per [JSON Reference](https://tools.ietf.org/html/draft-pbryan-zyp-json-ref-03), using the URL of the current document as the base URI. See also the [Reference Object](#referenceObject).

### Schema

In the following description, if a field is not explicitly **REQUIRED** or described with a MUST or SHALL, it can be considered OPTIONAL.

#### <a name="oasObject"></a>OpenAPI Object

This is the root document object of the [OpenAPI document](#oasDocument).

##### Fixed Fields

| Field Name                                 |                             Type                              | Pode CmdLets                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Description                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------ | :-----------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="oasVersion"></a>openapi           |                           `string`                            | [`Enable-PodeOpenApi`](https://badgerati.github.io/Pode/Functions/OpenApi/Enable-PodeOpenApi/)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | **REQUIRED**. This string MUST be the [semantic version number](https://semver.org/spec/v2.0.0.html) of the [OpenAPI Specification version](#versions) that the OpenAPI document uses. The `openapi` field SHOULD be used by tooling specifications and clients to interpret the OpenAPI document. This is *not* related to the API [`info.version`](#infoVersion) string.                                |
| <a name="oasInfo"></a>info                 |                  [Info Object](#infoObject)                   | [`Add-PodeOAInfo`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAInfo)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | **REQUIRED**. Provides metadata about the API. The metadata MAY be used by tooling as required.                                                                                                                                                                                                                                                                                                           |
| <a name="oasServers"></a>servers           |               [[Server Object](#serverObject)]                | [`Add-PodeOAServerEndpoint`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAServerEndpoint)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | An array of Server Objects, which provide connectivity information to a target server. If the `servers` property is not provided, or is an empty array, the default value would be a [Server Object](#serverObject) with a [url](#serverUrl) value of `/`.                                                                                                                                                |
| <a name="oasPaths"></a>paths               |                 [Paths Object](#pathsObject)                  | [`Add-PodeRoute`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeRoute)<br>[`Set-PodeOARouteInfo`](https://badgerati.github.io/Pode/Functions/OpenApi/Set-PodeOARouteInfo)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | **REQUIRED**. The available paths and operations for the API.                                                                                                                                                                                                                                                                                                                                             |
| <a name="oasComponents"></a>components     |            [Components Object](#componentsObject)             | [`Add-PodeOAComponentHeader`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentHeader)  <br>  [`Add-PodeOAComponentResponse`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentResponse) <br>[`Add-PodeOAComponentRequestBody`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentRequestBody)               <br>[`Add-PodeOAComponentParameter`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentParameter)<br> [`Add-PodeOAComponentSchema`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentSchema)  <br> [`Add-PodeOAComponentResponseLink`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentResponseLink)  <br>[`Add-PodeOAComponentCallBack`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentCallBack) | An element to hold various schemas for the specification.                                                                                                                                                                                                                                                                                                                                                 |
| <a name="oasSecurity"></a>security         |  [[Security Requirement Object](#securityRequirementObject)]  | [`New-PodeAuthScheme`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeAuthScheme)<br>             [`Merge-PodeAuthScheme`](https://badgerati.github.io/Pode/Functions/OpenApi/Merge-PodeAuthScheme) <br>                                               [`Add-PodeRoute`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeRoute)<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | A declaration of which security mechanisms can be used across the API. The list of values includes alternative security requirement objects that can be used. Only one of the security requirement objects need to be satisfied to authorize a request. Individual operations can override this definition. To make security optional, an empty security requirement (`{}`) can be included in the array. |
| <a name="oasTags"></a>tags                 |                  [[Tag Object](#tagObject)]                   | [`Add-PodeOATag`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOATag)                     <br>[`Set-PodeOARouteInfo`](https://badgerati.github.io/Pode/Functions/OpenApi/Set-PodeOARouteInfo)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | A list of tags used by the specification with additional metadata. The order of the tags can be used to reflect on their order by the parsing tools. Not all tags that are used by the [Operation Object](#operationObject) must be declared. The tags that are not declared MAY be organized randomly or based on the tools' logic. Each tag name in the list MUST be unique.                            |
| <a name="oasExternalDocs"></a>externalDocs | [External Documentation Object](#externalDocumentationObject) | [`Add-PodeOAExternalDoc`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAExternalDoc)                           <br>[`New-PodeOAExternalDoc`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeOAExternalDoc)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Additional external documentation.                                                                                                                                                                                                                                                                                                                                                                        |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

#### <a name="infoObject"></a>Info Object

The object provides metadata about the API.
The metadata MAY be used by the clients if needed, and MAY be presented in editing or documentation generation tools for convenience.

##### Fixed Fields

| Field Name                                      |               Type               | `Add-PodeOAInfo`                             | Description                                                                                                                                                    |
| ----------------------------------------------- | :------------------------------: | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="infoTitle"></a>title                   |             `string`             | `-Title`                                     | **REQUIRED**. The title of the API.                                                                                                                            |
| <a name="infoDescription"></a>description       |             `string`             | `-Description`                               | A short description of the API. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                    |
| <a name="infoTermsOfService"></a>termsOfService |             `string`             | `-TermOfService`                             | A URL to the Terms of Service for the API. MUST be in the format of a URL.                                                                                     |
| <a name="infoContact"></a>contact               | [Contact Object](#contactObject) | `-ContactName` `-ContactEmail` `-ContactUrl` | The contact information for the exposed API.                                                                                                                   |
| <a name="infoLicense"></a>license               | [License Object](#licenseObject) | `-LicenseName` `-LicenseUrl`                 | The license information for the exposed API.                                                                                                                   |
| <a name="infoVersion"></a>version               |             `string`             | `-Version`                                   | **REQUIRED**. The version of the OpenAPI document (which is distinct from the [OpenAPI Specification version](#oasVersion) or the API implementation version). |


This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Info Object Example
```Powershell
Add-PodeOAInfo -Title 'Sample Pet Store App' -Version 1.0.1 -Description 'This is a sample server for a pet store.' `
  -TermsOfService 'http://example.com/terms/' -LicenseName 'Apache 2.0' `
  -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' `
  -ContactEmail 'support@example.com' -ContactUrl 'http://example.com/support'
```

```json
{
  "title": "Sample Pet Store App",
  "description": "This is a sample server for a pet store.",
  "termsOfService": "http://example.com/terms/",
  "contact": {
    "name": "API Support",
    "url": "http://www.example.com/support",
    "email": "support@example.com"
  },
  "license": {
    "name": "Apache 2.0",
    "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
  },
  "version": "1.0.1"
}
```

```yaml
title: Sample Pet Store App
description: This is a sample server for a pet store.
termsOfService: http://example.com/terms/
contact:
  name: API Support
  url: http://www.example.com/support
  email: support@example.com
license:
  name: Apache 2.0
  url: https://www.apache.org/licenses/LICENSE-2.0.html
version: 1.0.1
```



#### <a name="contactObject"></a>Contact Object

Contact information for the exposed API.

##### Fixed Fields

| Field Name                       |   Type   | `Add-PodeOAInfo` | Description                                                                                      |
| -------------------------------- | :------: | ---------------- | ------------------------------------------------------------------------------------------------ |
| <a name="contactName"></a>name   | `string` | `-ContactName`   | The identifying name of the contact person/organization.                                         |
| <a name="contactUrl"></a>url     | `string` | `-ContactUrl`    | The URL pointing to the contact information. MUST be in the format of a URL.                     |
| <a name="contactEmail"></a>email | `string` | `-ContactEmail`  | The email address of the contact person/organization. MUST be in the format of an email address. |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Contact Object Example

```Powershell
Add-PodeOAInfo -ContactName 'API Support' -ContactUrl 'http://example.com/support' -ContactEmail 'support@example.com'
```

```json
{
  "name": "API Support",
  "url": "http://www.example.com/support",
  "email": "support@example.com"
}
```

```yaml
name: API Support
url: http://www.example.com/support
email: support@example.com
```

#### <a name="licenseObject"></a>License Object

License information for the exposed API.

##### Fixed Fields

| Field Name                     |   Type   | `Add-PodeOAInfo` | Description                                                            |
| ------------------------------ | :------: | ---------------- | ---------------------------------------------------------------------- |
| <a name="licenseName"></a>name | `string` | `-LicenseName`   | **REQUIRED**. The license name used for the API.                       |
| <a name="licenseUrl"></a>url   | `string` | `-LicenseUrl`    | A URL to the license used for the API. MUST be in the format of a URL. |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### License Object Example
```Powershell
Add-PodeOAInfo  -LicenseName 'Apache 2.0'  -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html'
```

```json
{
  "name": "Apache 2.0",
  "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
}
```

```yaml
name: Apache 2.0
url: https://www.apache.org/licenses/LICENSE-2.0.html
```

#### <a name="serverObject"></a>Server Object

An object representing a Server.

##### Fixed Fields

| Field Name                                  |                              Type                              | `Add-PodeOAServerEndpoint` | Description                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------------- | :------------------------------------------------------------: | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| <a name="serverUrl"></a>url                 |                            `string`                            | `-Url`                     | **REQUIRED**. A URL to the target host.  This URL supports Server Variables and MAY be relative, to indicate that the host location is relative to the location where the OpenAPI document is being served. Variable substitutions will be made when a variable is named in `{`brackets`}`.                                                                                                      |
| <a name="serverDescription"></a>description |                            `string`                            | `-Description`             | An optional string describing the host designated by the URL. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                                                                                        |
| <a name="serverVariables"></a>variables     | Map[`string`, [Server Variable Object](#serverVariableObject)] | `-Variable`                | A map between a variable name and its value.  The value is used for substitution in the server's URL template.         In Pode the OpenAPI Object's [`servers`](#oasServers) with variables can be defined using a `[ordered]@{}` [System.Collections.Specialized.OrderedDictionary](https://learn.microsoft.com/en-us/dotnet/api/system.collections.specialized.ordereddictionary?view=net-7.0) |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Server Object Example

A single server would be described as:

```Powershell
Add-PodeOAServerEndpoint -Url 'https://development.gigantic-server.com/v1' -Description 'Development server'
```

```json
{
  "url": "https://development.gigantic-server.com/v1",
  "description": "Development server"
}
```

```yaml
url: https://development.gigantic-server.com/v1
description: Development server
```



The following shows how multiple servers can be described, for example, at the OpenAPI Object's [`servers`](#oasServers):
```Powershell
Add-PodeOAServerEndpoint -url 'https://development.gigantic-server.com/v1' -Description 'Development server'
Add-PodeOAServerEndpoint -url 'https://staging.gigantic-server.com/v1' -Description 'Staging server'
Add-PodeOAServerEndpoint -url 'https://api.gigantic-server.com/v1' -Description 'Production server'
```
```json
{
  "servers": [
    {
      "url": "https://development.gigantic-server.com/v1",
      "description": "Development server"
    },
    {
      "url": "https://staging.gigantic-server.com/v1",
      "description": "Staging server"
    },
    {
      "url": "https://api.gigantic-server.com/v1",
      "description": "Production server"
    }
  ]
}
```

```yaml
servers:
- url: https://development.gigantic-server.com/v1
  description: Development server
- url: https://staging.gigantic-server.com/v1
  description: Staging server
- url: https://api.gigantic-server.com/v1
  description: Production server
```



The following shows how variables can be used for a server configuration:

```Powershell
Add-PodeOAServerEndpoint -Url "https://{username}.gigantic-server.com:{port}/{basePath}" `
  -Description "The production API server" -Variable  $(
    [ordered]@{
        username = @{
            default = 'demo'
            description = 'this value is assigned by the service provider, in this example gigantic-server.com'
        }
        port = @{
            enum = @( 8443, 443 )
            default = 8443
        }
        basePath = @{
            default = 'v2'
        }
    })
```
```json
{
  "servers": [
    {
      "url": "https://{username}.gigantic-server.com:{port}/{basePath}",
      "description": "The production API server",
      "variables": {
        "username": {
          "default": "demo",
          "description": "this value is assigned by the service provider, in this example `gigantic-server.com`"
        },
        "port": {
          "enum": [
            "8443",
            "443"
          ],
          "default": "8443"
        },
        "basePath": {
          "default": "v2"
        }
      }
    }
  ]
}
```

```yaml
servers:
- url: https://{username}.gigantic-server.com:{port}/{basePath}
  description: The production API server
  variables:
    username:
      # note! no enum here means it is an open value
      default: demo
      description: this value is assigned by the service provider, in this example `gigantic-server.com`
    port:
      enum:
        - '8443'
        - '443'
      default: '8443'
    basePath:
      # open meaning there is the opportunity to use special base paths as assigned by the provider, default is `v2`
      default: v2
```


#### <a name="serverVariableObject"></a>Server Variable Object

An object representing a Server Variable for server URL template substitution.

##### Fixed Fields

| Field Name                                          |    Type    | Description                                                                                                                                                                                                                                                                                                                                                                      |
| --------------------------------------------------- | :--------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="serverVariableEnum"></a>enum               | [`string`] | An enumeration of string values to be used if the substitution options are from a limited set. The array SHOULD NOT be empty.                                                                                                                                                                                                                                                    |
| <a name="serverVariableDefault"></a>default         |  `string`  | **REQUIRED**. The default value to use for substitution, which SHALL be sent if an alternate value is _not_ supplied. Note this behavior is different than the [Schema Object's](#schemaObject) treatment of default values, because in those cases parameter values are optional. If the [`enum`](#serverVariableEnum) is defined, the value SHOULD exist in the enum's values. |
| <a name="serverVariableDescription"></a>description |  `string`  | An optional description for the server variable. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                                                                                     |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

#### <a name="componentsObject"></a>Components Object

Holds a set of reusable objects for different aspects of the OAS.
All objects defined within the components object will have no effect on the API unless they are explicitly referenced from properties outside the components object.


##### Fixed Fields

| Field Name                                               | Type                                                                                                   | Pode                                                                                                                    | Description                                                                  |
| -------------------------------------------------------- | :----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| <a name="componentsSchemas"></a> schemas                 | Map[`string`, [Schema Object](#schemaObject) \| [Reference Object](#referenceObject)]                  | [`Add-PodeOAComponentSchema`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentSchema)             | An object to hold reusable [Schema Objects](#schemaObject).                  |
| <a name="componentsResponses"></a> responses             | Map[`string`, [Response Object](#responseObject) \| [Reference Object](#referenceObject)]              | [`Add-PodeOAComponentResponse`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentResponse)         | An object to hold reusable [Response Objects](#responseObject).              |
| <a name="componentsParameters"></a> parameters           | Map[`string`, [Parameter Object](#parameterObject) \| [Reference Object](#referenceObject)]            | [`Add-PodeOAComponentParameter`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentParameter)       | An object to hold reusable [Parameter Objects](#parameterObject).            | PodeOAComponentExample |
| <a name="componentsExamples"></a> examples               | Map[`string`, [Example Object](#exampleObject) \| [Reference Object](#referenceObject)]                | [`Add-PodeOAComponentExample`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentExample )          | An object to hold reusable [Example Objects](#exampleObject).                |
| <a name="componentsRequestBodies"></a> requestBodies     | Map[`string`, [Request Body Object](#requestBodyObject) \| [Reference Object](#referenceObject)]       | [`Add-PodeOAComponentRequestBody`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentRequestBody)   | An object to hold reusable [Request Body Objects](#requestBodyObject).       |
| <a name="componentsHeaders"></a> headers                 | Map[`string`, [Header Object](#headerObject) \| [Reference Object](#referenceObject)]                  | [`Add-PodeOAComponentHeader`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentHeader)             | An object to hold reusable [Header Objects](#headerObject).                  |
| <a name="componentsSecuritySchemes"></a> securitySchemes | Map[`string`, [Security Scheme Object](#securitySchemeObject) \| [Reference Object](#referenceObject)] | [`New-PodeAuthScheme`](https://badgerati.github.io/Pode/Functions/OpenApi/New-PodeAuthScheme)                           | An object to hold reusable [Security Scheme Objects](#securitySchemeObject). |
| <a name="componentsLinks"></a> links                     | Map[`string`, [Link Object](#linkObject) \| [Reference Object](#referenceObject)]                      | [`Add-PodeOAComponentResponseLink`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentResponseLink) | An object to hold reusable [Link Objects](#linkObject).                      |
| <a name="componentsCallbacks"></a> callbacks             | Map[`string`, [Callback Object](#callbackObject) \| [Reference Object](#referenceObject)]              | [`Add-PodeOAComponentCallBack`](https://badgerati.github.io/Pode/Functions/OpenApi/Add-PodeOAComponentCallBack)         | An object to hold reusable [Callback Objects](#callbackObject).              |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

All the fixed fields declared above are objects that MUST use keys that match the regular expression: `^[a-zA-Z0-9\.\-_]+$`.

Field Name Examples:

```
User
User_1
User_Name
user-name
my.org.User
```

##### Components Object Example
```powershell
New-PodeOAIntProperty -Name 'code' -Format Int32 |
  New-PodeOAStringProperty -Name 'message' |
  New-PodeOAObjectProperty |
  Add-PodeOAComponentSchema -Name 'GeneralError'

New-PodeOAStringProperty -Name 'name' |
  New-PodeOAIntProperty -Name 'id' -Format Int64 |
  New-PodeOAObjectProperty |
  Add-PodeOAComponentSchema -Name 'Category'

New-PodeOAStringProperty -Name 'name' |
  New-PodeOAIntProperty -Name 'id' -Format Int64 |
  New-PodeOAObjectProperty |
  Add-PodeOAComponentSchema -Name 'Tag'

Add-PodeOAComponentParameter -Name 'skipParam' -Parameter (
   New-PodeOAIntProperty -Name 'skip' -Format int32 -Description 'number of items to skip' -Required |
   ConvertTo-PodeOAParameter -In Query
)

Add-PodeOAComponentParameter -Name 'limitParam' -Parameter (
   New-PodeOAIntProperty -Name 'limit' -Format int32 -Description 'max records to return' -Required |
   ConvertTo-PodeOAParameter -In Query
)

Add-PodeOAComponentResponse -Name 'NotFound' -Description 'Entity not found.'
Add-PodeOAComponentResponse -Name 'IllegalInput' -Description 'Illegal input for operation.'
Add-PodeOAComponentResponse -Name 'GeneralError' -Description 'General Error' `
  -Content (@{'application/json' = 'GeneralError'})

New-PodeAuthScheme -ApiKey -Location Header | Add-PodeAuth -Name 'api_key' -Sessionless -ScriptBlock {
        param($key)
            #logic goes here
}

New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'read:pets' -Description 'read your pets'
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'write:pets' -Description 'modify pets in your account'

New-PodeAuthScheme -OAuth2 -ClientId $ClientId -ClientSecret $ClientSecret -AuthoriseUrl "http://example.org/api/oauth/dialog" `
  -TokenUrl 'http://example.org/api/oauth/token' -Scope 'read:pets', 'write:pets'  |
    Add-PodeAuth -Name 'petstore_auth' -FailureUrl 'http://example.org/api/oauth/dialog' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)
        return @{ User = $user }
    }
```
```json
"components": {
  "schemas": {
    "GeneralError": {
      "type": "object",
      "properties": {
        "code": {
          "type": "integer",
          "format": "int32"
        },
        "message": {
          "type": "string"
        }
      }
    },
    "Category": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "name": {
          "type": "string"
        }
      }
    },
    "Tag": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "name": {
          "type": "string"
        }
      }
    }
  },
  "parameters": {
    "skipParam": {
      "name": "skip",
      "in": "query",
      "description": "number of items to skip",
      "required": true,
      "schema": {
        "type": "integer",
        "format": "int32"
      }
    },
    "limitParam": {
      "name": "limit",
      "in": "query",
      "description": "max records to return",
      "required": true,
      "schema" : {
        "type": "integer",
        "format": "int32"
      }
    }
  },
  "responses": {
    "NotFound": {
      "description": "Entity not found."
    },
    "IllegalInput": {
      "description": "Illegal input for operation."
    },
    "GeneralError": {
      "description": "General Error",
      "content": {
        "application/json": {
          "schema": {
            "$ref": "#/components/schemas/GeneralError"
          }
        }
      }
    }
  },
  "securitySchemes": {
    "api_key": {
      "type": "apiKey",
      "name": "api_key",
      "in": "header"
    },
    "petstore_auth": {
      "type": "oauth2",
      "flows": {
        "password": {
          "authorizationUrl": "http://example.org/api/oauth/dialog",
          "tokenUrl": "http://example.org/api/oauth/token",
          "scopes": {
            "write:pets": "modify pets in your account",
            "read:pets": "read your pets"
          }
        }
      }
    }
  }
}
```

```yaml
components:
  schemas:
    GeneralError:
      type: object
      properties:
        code:
          type: integer
          format: int32
        message:
          type: string
    Category:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
    Tag:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
  parameters:
    skipParam:
      name: skip
      in: query
      description: number of items to skip
      required: true
      schema:
        type: integer
        format: int32
    limitParam:
      name: limit
      in: query
      description: max records to return
      required: true
      schema:
        type: integer
        format: int32
  responses:
    NotFound:
      description: Entity not found.
    IllegalInput:
      description: Illegal input for operation.
    GeneralError:
      description: General Error
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/GeneralError'
  securitySchemes:
    api_key:
      type: apiKey
      name: api_key
      in: header
    petstore_auth:
      type: oauth2
      flows:
        password:
          authorizationUrl: http://example.org/api/oauth/dialog
          tokenUrl: http://example.org/api/oauth/token
          scopes:
            write:pets: modify pets in your account
            read:pets: read your pets
```


#### <a name="pathsObject"></a>Paths Object

Holds the relative paths to the individual endpoints and their operations.
The path is appended to the URL from the [`Server Object`](#serverObject) in order to construct the full URL.  The Paths MAY be empty, due to [ACL constraints](#securityFiltering).

##### Patterned Fields

| Field Pattern                   |                Type                 | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------- | :---------------------------------: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="pathsPath"></a>/{path} | [Path Item Object](#pathItemObject) | A relative path to an individual endpoint. The field name MUST begin with a forward slash (`/`). The path is **appended** (no relative URL resolution) to the expanded URL from the [`Server Object`](#serverObject)'s `url` field in order to construct the full URL. [Path templating](#pathTemplating) is allowed. When matching URLs, concrete (non-templated) paths would be matched before their templated counterparts. Templated paths with the same hierarchy but different templated names MUST NOT exist as they are identical. In case of ambiguous matching, it's up to the tooling to decide which one to use. |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Path Templating Matching

Assuming the following paths, the concrete definition, `/pets/mine`, will be matched first if used:

```
  /pets/{petId}
  /pets/mine
```

The following paths are considered identical and invalid:

```
  /pets/{petId}
  /pets/{name}
```

The following may lead to ambiguous resolution:

```
  /{entity}/me
  /books/{id}
```

##### Paths Object Example

```powershell
 Add-PodeRoute -PassThru -Method Get -Path '/pets' -ScriptBlock {
            Write-PodeJsonResponse -Value (Get-Pets -All) -StatusCode 200
        } | Set-PodeOARouteInfo -Description 'Returns all pets from the system that the user has access to' -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'A list of pets.' -Default -Content (@{ 'application/json' = New-PodeOASchemaProperty -Reference 'Pet' -array })

```

```json
{
  "/pets": {
    "get": {
      "description": "Returns all pets from the system that the user has access to",
      "responses": {
        "200": {
          "description": "A list of pets.",
          "content": {
            "application/json": {
              "schema": {
                "type": "array",
                "items": {
                  "$ref": "#/components/schemas/pet"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

```yaml
/pets:
  get:
    description: Returns all pets from the system that the user has access to
    responses:
      '200':
        description: A list of pets.
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/pet'
```

#### <a name="pathItemObject"></a>Path Item Object

Describes the operations available on a single path.
A Path Item MAY be empty, due to [ACL constraints](#securityFiltering).
The path itself is still exposed to the documentation viewer but they will not know which operations and parameters are available.

##### Fixed Fields

| Field Name                                    |                                      Type                                      | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| --------------------------------------------- | :----------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="pathItemRef"></a>$ref                |                                    `string`                                    | (Unsupported by Pode) Allows for an external definition of this path item. The referenced structure MUST be in the format of a [Path Item Object](#pathItemObject).  In case a Path Item Object field appears both in the defined object and the referenced object, the behavior is undefined.                                                                                                                                                                                                                        |
| <a name="pathItemSummary"></a>summary         |                                    `string`                                    | An optional, string summary, intended to apply to all operations in this path.                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| <a name="pathItemDescription"></a>description |                                    `string`                                    | An optional, string description, intended to apply to all operations in this path. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                                                                                                                                                                                        |
| <a name="pathItemGet"></a>get                 |                      [Operation Object](#operationObject)                      | A definition of a GET operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| <a name="pathItemPut"></a>put                 |                      [Operation Object](#operationObject)                      | A definition of a PUT operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| <a name="pathItemPost"></a>post               |                      [Operation Object](#operationObject)                      | A definition of a POST operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| <a name="pathItemDelete"></a>delete           |                      [Operation Object](#operationObject)                      | A definition of a DELETE operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| <a name="pathItemOptions"></a>options         |                      [Operation Object](#operationObject)                      | A definition of a OPTIONS operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| <a name="pathItemHead"></a>head               |                      [Operation Object](#operationObject)                      | A definition of a HEAD operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| <a name="pathItemPatch"></a>patch             |                      [Operation Object](#operationObject)                      | A definition of a PATCH operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| <a name="pathItemTrace"></a>trace             |                      [Operation Object](#operationObject)                      | A definition of a TRACE operation on this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| <a name="pathItemServers"></a>servers         |                        [[Server Object](#serverObject)]                        | An alternative `server` array to service all operations in this path.                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| <a name="pathItemParameters"></a>parameters   | [[Parameter Object](#parameterObject) \| [Reference Object](#referenceObject)] | A list of parameters that are applicable for all the operations described under this path. These parameters can be overridden at the operation level, but cannot be removed there. The list MUST NOT include duplicated parameters. A unique parameter is defined by a combination of a [name](#parameterName) and [location](#parameterIn). The list can use the [Reference Object](#referenceObject) to link to parameters that are defined at the [OpenAPI Object's components/parameters](#componentsParameters). |


This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Path Item Object Example
```powershell
Add-PodeRoute -PassThru -Method Get -Path '/peta/:id' -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-Pet -Id $WebEvent.Parameters['id']) -StatusCode 200
    } |
      Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
      Set-PodeOARequest -PassThru -Parameters @(
      (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
      Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -Reference 'Pet' -array }) -PassThru |
      Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
```
```json
{
  "get": {
    "description": "Returns pets based on ID",
    "summary": "Find pets by ID",
    "operationId": "getPetsById",
    "responses": {
      "200": {
        "description": "pet response",
        "content": {
          "*/*": {
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/components/schemas/Pet"
              }
            }
          }
        }
      },
      "default": {
        "description": "error payload",
        "content": {
          "text/html": {
            "schema": {
              "$ref": "#/components/schemas/ErrorModel"
            }
          }
        }
      }
    }
  },
  "parameters": [
    {
      "name": "id",
      "in": "path",
      "description": "ID of pet to use",
      "required": true,
      "schema": {
        "type": "array",
        "items": {
          "type": "string"
        }
      },
      "style": "simple"
    }
  ]
}
```

```yaml
get:
  description: Returns pets based on ID
  summary: Find pets by ID
  operationId: getPetsById
  responses:
    '200':
      description: pet response
      content:
        '*/*' :
          schema:
            type: array
            items:
              $ref: '#/components/schemas/Pet'
    default:
      description: error payload
      content:
        'text/html':
          schema:
            $ref: '#/components/schemas/ErrorModel'
parameters:
- name: id
  in: path
  description: ID of pet to use
  required: true
  schema:
    type: array
    items:
      type: string
  style: simple
```



##### Path Item Object Example with External Servers
```powershell
Add-PodeOAExternalRoute -PassThru -Method Get -Path '/peta/:id' -Servers (
  New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
  New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13'
  ) |
      Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
      Set-PodeOARequest -PassThru -Parameters @(
      (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
      Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -Reference 'Pet' -array }) -PassThru |
      Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
```
```json
{
  "get": {
    "description": "Returns pets based on ID",
    "summary": "Find pets by ID",
    "operationId": "getPetsById",
    "responses": {
      "200": {
        "description": "pet response",
        "content": {
          "*/*": {
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/components/schemas/Pet"
              }
            }
          }
        }
      },
      "default": {
        "description": "error payload",
        "content": {
          "text/html": {
            "schema": {
              "$ref": "#/components/schemas/ErrorModel"
            }
          }
        }
      }
    }
  },
  "servers": [
    {
      "description": "ext test server",
      "url": "http://ext.server.com/api/v12"
    },
    {
      "description": "ext test server 13",
      "url": "http://ext13.server.com/api/v12"
    }
  ],
  "parameters": [
    {
      "name": "id",
      "in": "path",
      "description": "ID of pet to use",
      "required": true,
      "schema": {
        "type": "array",
        "items": {
          "type": "string"
        }
      },
      "style": "simple"
    }
  ]
}
```

```yaml
get:
  description: Returns pets based on ID
  summary: Find pets by ID
  operationId: getPetsById
  responses:
    '200':
      description: pet response
      content:
        '*/*' :
          schema:
            type: array
            items:
              $ref: '#/components/schemas/Pet'
    default:
      description: error payload
      content:
        'text/html':
          schema:
            $ref: '#/components/schemas/ErrorModel'
    servers:
        - description : ext test server
          url : http://ext.server.com/api/v12
        - description : ext test server 13
          url : http://ext13.server.com/api/v12
parameters:
- name: id
  in: path
  description: ID of pet to use
  required: true
  schema:
    type: array
    items:
      type: string
  style: simple
```



#### <a name="operationObject"></a>Operation Object

Describes a single API operation on a path.

##### Fixed Fields
```powershell
# Authentication Login-OAuth2
New-PodeAuthScheme `
  -OAuth2 `
  -ClientId $ClientId `
  -ClientSecret $ClientSecret `
  -AuthoriseUrl 'http://example.org/api/oauth/dialog' `
  -TokenUrl 'http://example.org/api/oauth/token' `
  -Scope 'read', 'write' | Add-PodeAuth -Name 'Login-OAuth2' -FailureUrl '/LoginOAuth2' -SuccessUrl '/' -ScriptBlock {
    param($user, $accessToken, $refreshToken)
    return @{ User = $user }
  }

# Reference to external documentation
New-PodeOAExternalDoc -Name 'OpenApiDocs' -Description 'Find out more about OpenApi' -Url 'https://www.openapis.org/'

# The variable $Route used in this table is defined as:
$Route = Add-PodeRoute -PassThru -Method Get -Path '/pet/:petId' -ScriptBlock {
   Write-PodeJsonResponse -Value (Get-Pet -Id $WebEvent.Parameters['id']) -StatusCode 200
   }
```

| Field Name                                       |                                           Type                                            | `Set-PodeOARouteInfo` | Description                                                                                                                                                                                                                                                                                                              |
| ------------------------------------------------ | :---------------------------------------------------------------------------------------: | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| <a name="operationTags"></a>tags                 |                                        [`string`]                                         | `-Tags`               | A list of tags for API documentation control. Tags can be used for logical grouping of operations by resources or any other qualifier.                                                                                                                                                                                   |
| <a name="operationSummary"></a>summary           |                                         `string`                                          | `-Summary`            | A short summary of what the operation does.                                                                                                                                                                                                                                                                              |
| <a name="operationDescription"></a>description   |                                         `string`                                          | `-Description`        | A verbose explanation of the operation behavior. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                             |
| <a name="operationExternalDocs"></a>externalDocs |               [External Documentation Object](#externalDocumentationObject)               | `-ExternalDocs`       | Additional external documentation for this operation.                                                                                                                                                                                                                                                                    |
| <a name="operationId"></a>operationId            |                                         `string`                                          | `-OperationId`        | Unique string used to identify the operation. The id MUST be unique among all operations described in the API. The operationId value is **case-sensitive**. Tools and libraries MAY use the operationId to uniquely identify an operation, therefore, it is RECOMMENDED to follow common programming naming conventions. |
| <a name="operationCallbacks"></a>callbacks       | Map[`string`, [Callback Object](#callbackObject) \| [Reference Object](#referenceObject)] | TBD                   | A map of possible out-of band callbacks related to the parent operation. The key is a unique identifier for the Callback Object. Each value in the map is a [Callback Object](#callbackObject) that describes a request that may be initiated by the API provider and the expected responses.                            |
| <a name="operationDeprecated"></a>deprecated     |                                         `boolean`                                         | `-Deprecated`         | Declares this operation to be deprecated. Consumers SHOULD refrain from usage of the declared operation. Default value is `false`.                                                                                                                                                                                       |
| <a name="operationServers"></a>servers           |                             [[Server Object](#serverObject)]                              | TBD                   | An alternative `server` array to service this operation. If an alternative `server` object is specified at the Path Item Object or Root level, it will be overridden by this value.                                                                                                                                      |

| Field Name                                     |                                       Type                                        | `Set-PodeOARequest` | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------------------------------------------- | :-------------------------------------------------------------------------------: | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="operationParameters"></a>parameters   |  [[Parameter Object](#parameterObject) \| [Reference Object](#referenceObject)]   | `-Parameters`       | A list of parameters that are applicable for this operation. If a parameter is already defined at the [Path Item](#pathItemParameters), the new definition will override it but can never remove it. The list MUST NOT include duplicated parameters. A unique parameter is defined by a combination of a [name](#parameterName) and [location](#parameterIn). The list can use the [Reference Object](#referenceObject) to link to parameters that are defined at the [OpenAPI Object's components/parameters](#componentsParameters). |
| <a name="operationRequestBody"></a>requestBody | [Request Body Object](#requestBodyObject) \| [Reference Object](#referenceObject) | `-RequestBody`      | The request body applicable for this operation.  The `requestBody` is only supported in HTTP methods where the HTTP 1.1 specification [RFC7231](https://tools.ietf.org/html/rfc7231#section-4.3.1) has explicitly defined semantics for request bodies.  In other cases where the HTTP spec is vague, `requestBody` SHALL be ignored by consumers.                                                                                                                                                                                      |



| Field Name                                 |                 Type                 | `Set-PodeOAResponse` | Description                                                                                      |
| ------------------------------------------ | :----------------------------------: | -------------------- | ------------------------------------------------------------------------------------------------ |
| <a name="operationResponses"></a>responses | [Responses Object](#responsesObject) |                      | **REQUIRED**. The list of possible responses as they are returned from executing this operation. |



| Field Name                               |                            Type                             | `Add-PodeRoute`                     | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------------------- | :---------------------------------------------------------: | ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="operationSecurity"></a>security | [[Security Requirement Object](#securityRequirementObject)] | `-Authentication` `-Scope         ` | A declaration of which security mechanisms can be used for this operation. The list of values includes alternative security requirement objects that can be used. Only one of the security requirement objects need to be satisfied to authorize a request. To make security optional, an empty security requirement (`{}`) can be included in the array. This definition overrides any declared top-level [`security`](#oasSecurity). To remove a top-level security declaration, an empty array can be used. |


| Field Name                                 |                                           Type                                            | Unsupported | Description                                                                                                                                                                                                                                                                                   |
| ------------------------------------------ | :---------------------------------------------------------------------------------------: | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="operationCallbacks"></a>callbacks | Map[`string`, [Callback Object](#callbackObject) \| [Reference Object](#referenceObject)] |             | A map of possible out-of band callbacks related to the parent operation. The key is a unique identifier for the Callback Object. Each value in the map is a [Callback Object](#callbackObject) that describes a request that may be initiated by the API provider and the expected responses. |
| <a name="operationServers"></a>servers     |                             [[Server Object](#serverObject)]                              |             | An alternative `server` array to service this operation. If an alternative `server` object is specified at the Path Item Object or Root level, it will be overridden by this value.                                                                                                           |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Operation Object Example
```powershell
 Add-PodeRoute -PassThru -Method Put -Path '/pet' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $JsonPet = ConvertTo-Json $WebEvent.data
           if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet){
                Write-PodeJsonResponse -Value @{} -StatusCode 200
            } else {
                Write-PodeJsonResponse -Value @{} -StatusCode 405
            }
        } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatePetWithForm' -PassThru |
            Set-PodeOARequest  -Parameters @(
              (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
            ) -RequestBody (New-PodeOARequestBody -Required -Content (@{
                'application/x-www-form-urlencoded' = New-PodeOAObjectProperty -Properties @(
                  (New-PodeOAStringProperty -Name 'name' -Description 'Updated name of the pet'),
                  (New-PodeOAStringProperty -Name 'status' -Description 'Updated status of the pet' -Required)
                  )
                })
              ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -Content (@{ 'application/json' = '' ; 'application/xml' = '' }) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -Content  (@{ 'application/json' = '' ; 'application/xml' = '' })
```
```json
{
  "tags": [
    "pet"
  ],
  "summary": "Updates a pet in the store with form data",
  "operationId": "updatePetWithForm",
  "parameters": [
    {
      "name": "petId",
      "in": "path",
      "description": "ID of pet that needs to be updated",
      "required": true,
      "schema": {
        "type": "string"
      }
    }
  ],
  "requestBody": {
    "content": {
      "application/x-www-form-urlencoded": {
        "schema": {
          "type": "object",
          "properties": {
            "name": {
              "description": "Updated name of the pet",
              "type": "string"
            },
            "status": {
              "description": "Updated status of the pet",
              "type": "string"
            }
          },
          "required": ["status"]
        }
      }
    }
  },
  "responses": {
    "200": {
      "description": "Pet updated.",
      "content": {
        "application/json": {},
        "application/xml": {}
      }
    },
    "405": {
      "description": "Method Not Allowed",
      "content": {
        "application/json": {},
        "application/xml": {}
      }
    }
  },
  "security": [
    {
      "petstore_auth": [
        "write:pets",
        "read:pets"
      ]
    }
  ]
}
```

```yaml
tags:
- pet
summary: Updates a pet in the store with form data
operationId: updatePetWithForm
parameters:
- name: petId
  in: path
  description: ID of pet that needs to be updated
  required: true
  schema:
    type: string
requestBody:
  content:
    'application/x-www-form-urlencoded':
      schema:
       properties:
          name:
            description: Updated name of the pet
            type: string
          status:
            description: Updated status of the pet
            type: string
       required:
         - status
responses:
  '200':
    description: Pet updated.
    content:
      'application/json': {}
      'application/xml': {}
  '405':
    description: Method Not Allowed
    content:
      'application/json': {}
      'application/xml': {}
security:
- petstore_auth:
  - write:pets
  - read:pets
```


#### <a name="externalDocumentationObject"></a>External Documentation Object

Allows referencing an external resource for extended documentation.

##### Fixed Fields

| Field Name                                       |   Type   | `PodeOAExternalDoc` | Description                                                                                                                                  |
| ------------------------------------------------ | :------: | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="externalDocDescription"></a>description | `string` | `-Description`      | A short description of the target documentation. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation. |
| <a name="externalDocUrl"></a>url                 | `string` | `-Url`              | **REQUIRED**. The URL for the target documentation. Value MUST be in the format of a URL.                                                    |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### External Documentation Object Example
```powershell
New-PodeOAExternalDoc  -Name 'ExampleDoc' -Description 'Find more info here' -Url 'https://example.com"
}'
Add-PodeRoute -PassThru -Method Put -Path '/pet' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock { # code here
        } | Set-PodeOARouteInfo -ExternalDoc 'ExampleDoc' -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatePetWithForm' -PassThru | # Continue .....
```
```json
{
  "description": "Find more info here",
  "url": "https://example.com"
}
```

```yaml
description: Find more info here
url: https://example.com
```

#### <a name="parameterObject"></a>Parameter Object

Describes a single operation parameter.

A unique parameter is defined by a combination of a [name](#parameterName) and [location](#parameterIn).

##### Parameter Locations
There are four possible parameter locations specified by the `in` field:
* path - Used together with [Path Templating](#pathTemplating), where the parameter value is actually part of the operation's URL. This does not include the host or base path of the API. For example, in `/items/{itemId}`, the path parameter is `itemId`.
* query - Parameters that are appended to the URL. For example, in `/items?id=###`, the query parameter is `id`.
* header - Custom headers that are expected as part of the request. Note that [RFC7230](https://tools.ietf.org/html/rfc7230#page-22) states header names are case insensitive.
* cookie - Used to pass a specific cookie value to the API.


##### Fixed Fields
| Field Name                                              |   Type    | `ConvertTo-PodeOAParameter` | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------- | :-------: | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| <a name="parameterName"></a>name                        | `string`  | `-Name`                     | **REQUIRED**. The name of the parameter. Parameter names are *case sensitive*. <ul><li>If [`in`](#parameterIn) is `"path"`, the `name` field MUST correspond to a template expression occurring within the [path](#pathsPath) field in the [Paths Object](#pathsObject). See [Path Templating](#pathTemplating) for further information.<li>If [`in`](#parameterIn) is `"header"` and the `name` field is `"Accept"`, `"Content-Type"` or `"Authorization"`, the parameter definition SHALL be ignored.<li>For all other cases, the `name` corresponds to the parameter name used by the [`in`](#parameterIn) property.</ul>Note. In Pode if the -Name parameter is not used the name of the Property created by `New-PodeOAIntProperty`, `New-PodeOANumberProperty`, `New-PodeOABoolProperty `,  `New-PodeOAStringProperty`,  `New-PodeOAObjectProperty` is used. |
| <a name="parameterIn"></a>in                            | `string`  | `-In`                       | **REQUIRED**. The location of the parameter. Possible values are `"query"`, `"header"`, `"path"` or `"cookie"`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| <a name="parameterDescription"></a>description          | `string`  | `-Description`              | A brief description of the parameter. This could contain examples of use. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| <a name="parameterRequired"></a>required                | `boolean` | `-Required`                 | Determines whether this parameter is mandatory. If the [parameter location](#parameterIn) is `"path"`, this property is **REQUIRED** and its value MUST be `true`. Otherwise, the property MAY be included and its default value is `false`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| <a name="parameterDeprecated"></a> deprecated           | `boolean` | `-Deprecated`               | Specifies that a parameter is deprecated and SHOULD be transitioned out of usage. Default value is `false`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| <a name="parameterAllowEmptyValue"></a> allowEmptyValue | `boolean` | `-AllowEmptyValue`          | Sets the ability to pass empty-valued parameters. This is valid only for `query` parameters and allows sending a parameter with an empty value. Default value is `false`. If [`style`](#parameterStyle) is used, and if behavior is `n/a` (cannot be serialized), the value of `allowEmptyValue` SHALL be ignored. Use of this property is NOT RECOMMENDED, as it is likely to be removed in a later revision.                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

The rules for serialization of the parameter are specified in one of two ways.
For simpler scenarios, a [`schema`](#parameterSchema) and [`style`](#parameterStyle) can describe the structure and syntax of the parameter.

| Field Name                                         |                                           Type                                           | `ConvertTo-PodeOAParameter` | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| -------------------------------------------------- | :--------------------------------------------------------------------------------------: | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="parameterStyle"></a>style                 |                                         `string`                                         | `-Style`                    | Describes how the parameter value will be serialized depending on the type of the parameter value. Default values (based on value of `in`): for `query` - `form`; for `path` - `simple`; for `header` - `simple`; for `cookie` - `form`.                                                                                                                                                                                                                                                                    |
| <a name="parameterExplode"></a>explode             |                                        `boolean`                                         | `-Explode`                  | When this is true, parameter values of type `array` or `object` generate separate parameters for each value of the array or key-value pair of the map. For other types of parameters this property has no effect. When [`style`](#parameterStyle) is `form`, the default value is `true`. For all other styles, the default value is `false`.                                                                                                                                                               |
| <a name="parameterAllowReserved"></a>allowReserved |                                        `boolean`                                         | `-AllowReserved`            | Determines whether the parameter value SHOULD allow reserved characters, as defined by [RFC3986](https://tools.ietf.org/html/rfc3986#section-2.2) `:/?#[]@!$&'()*+,;=` to be included without percent-encoding. This property only applies to parameters with an `in` value of `query`. The default value is `false`.                                                                                                                                                                                       |
| <a name="parameterSchema"></a>schema               |          [Schema Object](#schemaObject) \| [Reference Object](#referenceObject)          | `-Schema`                   | The schema defining the type used for the parameter.                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| <a name="parameterExample"></a>example             |                                           Any                                            | `-Example`                  | Example of the parameter's potential value. The example SHOULD match the specified schema and encoding properties if present. The `example` field is mutually exclusive of the `examples` field. Furthermore, if referencing a `schema` that contains an example, the `example` value SHALL _override_ the example provided by the schema. To represent examples of media types that cannot naturally be represented in JSON or YAML, a string value can contain the example with escaping where necessary. |
| <a name="parameterExamples"></a>examples           | Map[ `string`, [Example Object](#exampleObject) \| [Reference Object](#referenceObject)] | `-Examples`                 | Examples of the parameter's potential value. Each example SHOULD contain a value in the correct format as specified in the parameter encoding. The `examples` field is mutually exclusive of the `example` field. Furthermore, if referencing a `schema` that contains an example, the `examples` value SHALL _override_ the example provided by the schema.                                                                                                                                                |

For more complex scenarios, the [`content`](#parameterContent) property can define the media type and schema of the parameter.
A parameter MUST contain either a `schema` property, or a `content` property, but not both.
When `example` or `examples` are provided in conjunction with the `schema` object, the example MUST follow the prescribed serialization strategy for the parameter.


| Field Name                             |                         Type                         | `ConvertTo-PodeOAParameter` | Description                                                                                                                                        |
| -------------------------------------- | :--------------------------------------------------: | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="parameterContent"></a>content | Map[`string`, [Media Type Object](#mediaTypeObject)] | `-Content`                  | A map containing the representations for the parameter. The key is the media type and the value describes it. The map MUST only contain one entry. |

##### Style Values

In order to support common ways of serializing simple parameters, a set of `style` values are defined.

| `style`        | [`type`](#dataTypes)           | `in`              | Comments                                                                                                                                                                                                                                  |
| -------------- | ------------------------------ | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| matrix         | `primitive`, `array`, `object` | `path`            | Path-style parameters defined by [RFC6570](https://tools.ietf.org/html/rfc6570#section-3.2.7)                                                                                                                                             |
| label          | `primitive`, `array`, `object` | `path`            | Label style parameters defined by [RFC6570](https://tools.ietf.org/html/rfc6570#section-3.2.5)                                                                                                                                            |
| form           | `primitive`, `array`, `object` | `query`, `cookie` | Form style parameters defined by [RFC6570](https://tools.ietf.org/html/rfc6570#section-3.2.8). This option replaces `collectionFormat` with a `csv` (when `explode` is false) or `multi` (when `explode` is true) value from OpenAPI 2.0. |
| simple         | `array`                        | `path`, `header`  | Simple style parameters defined by [RFC6570](https://tools.ietf.org/html/rfc6570#section-3.2.2).  This option replaces `collectionFormat` with a `csv` value from OpenAPI 2.0.                                                            |
| spaceDelimited | `array`                        | `query`           | Space separated array values. This option replaces `collectionFormat` equal to `ssv` from OpenAPI 2.0.                                                                                                                                    |
| pipeDelimited  | `array`                        | `query`           | Pipe separated array values. This option replaces `collectionFormat` equal to `pipes` from OpenAPI 2.0.                                                                                                                                   |
| deepObject     | `object`                       | `query`           | Provides a simple way of rendering nested objects using form parameters.                                                                                                                                                                  |


##### Style Examples

Assume a parameter named `color` has one of the following values:

```
   string -> "blue"
   array -> ["blue","black","brown"]
   object -> { "R": 100, "G": 200, "B": 150 }
```
The following table shows examples of rendering differences for each value.

| [`style`](#dataTypeFormat) | `explode` | `empty` | `string`    | `array`                             | `object`                               |
| -------------------------- | --------- | ------- | ----------- | ----------------------------------- | -------------------------------------- |
| matrix                     | false     | ;color  | ;color=blue | ;color=blue,black,brown             | ;color=R,100,G,200,B,150               |
| matrix                     | true      | ;color  | ;color=blue | ;color=blue;color=black;color=brown | ;R=100;G=200;B=150                     |
| label                      | false     | .       | .blue       | .blue.black.brown                   | .R.100.G.200.B.150                     |
| label                      | true      | .       | .blue       | .blue.black.brown                   | .R=100.G=200.B=150                     |
| form                       | false     | color=  | color=blue  | color=blue,black,brown              | color=R,100,G,200,B,150                |
| form                       | true      | color=  | color=blue  | color=blue&color=black&color=brown  | R=100&G=200&B=150                      |
| simple                     | false     | n/a     | blue        | blue,black,brown                    | R,100,G,200,B,150                      |
| simple                     | true      | n/a     | blue        | blue,black,brown                    | R=100,G=200,B=150                      |
| spaceDelimited             | false     | n/a     | n/a         | blue%20black%20brown                | R%20100%20G%20200%20B%20150            |
| pipeDelimited              | false     | n/a     | n/a         | blue\|black\|brown                  | R\|100\|G\|200\|B\|150                 |
| deepObject                 | true      | n/a     | n/a         | n/a                                 | color[R]=100&color[G]=200&color[B]=150 |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Parameter Object Examples

A header parameter with an array of 64 bit integer numbers:
```powershell
New-PodeOAIntProperty -Name 'token' -Description 'token to be passed as a header' -Array -Format Int64 |
  ConvertTo-PodeOAParameter -In Header -Style Simple -Required
```
```json
{
  "name": "token",
  "in": "header",
  "description": "token to be passed as a header",
  "required": true,
  "schema": {
    "type": "array",
    "items": {
      "type": "integer",
      "format": "int64"
    }
  },
  "style": "simple"
}
```

```yaml
name: token
in: header
description: token to be passed as a header
required: true
schema:
  type: array
  items:
    type: integer
    format: int64
style: simple
```

A path parameter of a string value:
```powershell
New-PodeOAStringProperty -Name 'username' -Description 'username to fetch' |
  ConvertTo-PodeOAParameter -In Path -Required
```
```json
{
  "name": "username",
  "in": "path",
  "description": "username to fetch",
  "required": true,
  "schema": {
    "type": "string"
  }
}
```

```yaml
name: username
in: path
description: username to fetch
required: true
schema:
  type: string
```

An optional query parameter of a string value, allowing multiple values by repeating the query parameter:
```powershell
New-PodeOAStringProperty -Name 'id' -Description 'ID of the object to fetch' -Array   |
  ConvertTo-PodeOAParameter -In Query -Style Form
```
```json
{
  "name": "id",
  "in": "query",
  "description": "ID of the object to fetch",
  "required": false,
  "schema": {
    "type": "array",
    "items": {
      "type": "string"
    }
  },
  "style": "form",
  "explode": true
}
```

```yaml
name: id
in: query
description: ID of the object to fetch
required: false
schema:
  type: array
  items:
    type: string
style: form
explode: true
```

A free-form query parameter, allowing undefined parameters of a specific type:
```powershell
New-PodeOAIntProperty -Name 'freeForm' -Object |
  ConvertTo-PodeOAParameter -In Query -Style Form
```
```json
{
  "in": "query",
  "name": "freeForm",
  "schema": {
    "type": "object",
    "additionalProperties": {
      "type": "integer"
    },
  },
  "style": "form"
}
```

```yaml
in: query
name: freeForm
schema:
  type: object
  additionalProperties:
    type: integer
style: form
```

A complex parameter using `content` to define serialization:
```powershell
  ConvertTo-PodeOAParameter -In Query -Schema @{'application/json' = (
    New-PodeOANumberProperty -Name 'lat' -Required |
      New-PodeOANumberProperty -Name 'long' -Required |
      New-PodeOAObjectProperty
  )}
```
```json
{
  "in": "query",
  "name": "coordinates",
  "content": {
    "application/json": {
      "schema": {
        "type": "object",
        "required": [
          "lat",
          "long"
        ],
        "properties": {
          "lat": {
            "type": "number"
          },
          "long": {
            "type": "number"
          }
        }
      }
    }
  }
}
```

```yaml
in: query
name: coordinates
content:
  application/json:
    schema:
      type: object
      required:
        - lat
        - long
      properties:
        lat:
          type: number
        long:
          type: number
```

#### <a name="requestBodyObject"></a>Request Body Object

Describes a single request body.

##### Fixed Fields
| Field Name                                       |                         Type                         | `New-PodeOARequestBody` | Description                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------ | :--------------------------------------------------: | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="requestBodyDescription"></a>description |                       `string`                       | `-Description`          | A brief description of the request body. This could contain examples of use.  [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                   |
| <a name="requestBodyContent"></a>content         | Map[`string`, [Media Type Object](#mediaTypeObject)] | `-Content`              | **REQUIRED**. The content of the request body. The key is a media type or [media type range](https://tools.ietf.org/html/rfc7231#appendix-D) and the value describes it.  For requests that match multiple keys, only the most specific key is applicable. e.g. text/plain overrides text/* |
| <a name="requestBodyRequired"></a>required       |                      `boolean`                       | `-Required`             | Determines if the request body is required in the request. Defaults to `false`.                                                                                                                                                                                                             |


This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Request Body Examples

A request body with a referenced model definition.
```powershell
New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'User'; 'application/xml' = 'User'}  -Examples (
  New-PodeOAExample -MediaType 'application/json' -Name 'user' -Summary 'User Example' -ExternalValue 'http://foo.bar/examples/user-example.json' |
    New-PodeOAExample -MediaType 'application/xml' -Name 'user' -Summary 'User Example in XML' -ExternalValue 'http://foo.bar/examples/user-example.xml' |
    New-PodeOAExample -MediaType 'text/plain' -Name 'user' -Summary 'User Example in Plain text' -ExternalValue 'http://foo.bar/examples/user-example.txt' |
    New-PodeOAExample -MediaType '*/*' -Name 'user' -Summary 'User example in other format' -ExternalValue 'http://foo.bar/examples/user-example.whatever'
  )
```
```json
{
  "description": "user to add to the system",
  "content": {
    "application/json": {
      "schema": {
        "$ref": "#/components/schemas/User"
      },
      "examples": {
          "user" : {
            "summary": "User Example",
            "externalValue": "http://foo.bar/examples/user-example.json"
          }
        }
    },
    "application/xml": {
      "schema": {
        "$ref": "#/components/schemas/User"
      },
      "examples": {
          "user" : {
            "summary": "User example in XML",
            "externalValue": "http://foo.bar/examples/user-example.xml"
          }
        }
    },
    "text/plain": {
      "examples": {
        "user" : {
            "summary": "User example in Plain text",
            "externalValue": "http://foo.bar/examples/user-example.txt"
        }
      }
    },
    "*/*": {
      "examples": {
        "user" : {
            "summary": "User example in other format",
            "externalValue": "http://foo.bar/examples/user-example.whatever"
        }
      }
    }
  }
}
```

```yaml
description: user to add to the system
content:
  'application/json':
    schema:
      $ref: '#/components/schemas/User'
    examples:
      user:
        summary: User Example
        externalValue: 'http://foo.bar/examples/user-example.json'
  'application/xml':
    schema:
      $ref: '#/components/schemas/User'
    examples:
      user:
        summary: User Example in XML
        externalValue: 'http://foo.bar/examples/user-example.xml'
  'text/plain':
    examples:
      user:
        summary: User example in text plain format
        externalValue: 'http://foo.bar/examples/user-example.txt'
  '*/*':
    examples:
      user:
        summary: User example in other format
        externalValue: 'http://foo.bar/examples/user-example.whatever'
```

A body parameter that is an array of string values:
```powershell
New-PodeOARequestBody -Description 'user to add to the system' -Content @{
  'text/plain' =   New-PodeOAStringProperty -Name 'breed' -array
}
```
```json
{
  "description": "user to add to the system",
  "content": {
    "text/plain": {
      "schema": {
        "type": "array",
        "items": {
          "type": "string"
        }
      }
    }
  }
}
```

```yaml
description: user to add to the system
required: true
content:
  text/plain:
    schema:
      type: array
      items:
        type: string
```


#### <a name="mediaTypeObject"></a>Media Type Object
Each Media Type Object provides schema and examples for the media type identified by its key.

##### Fixed Fields
| Field Name                               |                                           Type                                           | `New-PodeOARequestBody` | Description                                                                                                                                                                                                                                                                                                                     |
| ---------------------------------------- | :--------------------------------------------------------------------------------------: | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="mediaTypeSchema"></a>schema     |          [Schema Object](#schemaObject) \| [Reference Object](#referenceObject)          | `-Schema`               | The schema defining the content of the request, response, or parameter.                                                                                                                                                                                                                                                         |
| <a name="mediaTypeExample"></a>example   |                                           Any                                            | `Not Supported`         | Example of the media type.  The example object SHOULD be in the correct format as specified by the media type.  The `example` field is mutually exclusive of the `examples` field.  Furthermore, if referencing a `schema` which contains an example, the `example` value SHALL _override_ the example provided by the schema.  |
| <a name="mediaTypeExamples"></a>examples | Map[ `string`, [Example Object](#exampleObject) \| [Reference Object](#referenceObject)] | `-Examples`             | Examples of the media type.  Each example object SHOULD  match the media type and specified schema if present.  The `examples` field is mutually exclusive of the `example` field.  Furthermore, if referencing a `schema` which contains an example, the `examples` value SHALL _override_ the example provided by the schema. |
| <a name="mediaTypeEncoding"></a>encoding |                    Map[`string`, [Encoding Object](#encodingObject)]                     | `Not Supported`         | A map between a property name and its encoding information. The key, being the property name, MUST exist in the schema as a property. The encoding object SHALL only apply to `requestBody` objects when the media type is `multipart` or `application/x-www-form-urlencoded`.                                                  |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Media Type Examples
```powershell
New-PodeOARequestBody -Content @{ 'application/json' = 'Pet' } -Examples (
  New-PodeOAExample -MediaType 'application/json' -Name 'cat' -Summary 'An example of a cat' -Value  @{name = 'Fluffy'; petType = 'Cat'; color = 'White'; gender = 'male'; breed = 'Persian' } |
    New-PodeOAExample -MediaType 'application/json' -Name 'dog' -Summary "An example of a dog with a cat's name" -Value    @{name = 'Puma'; petType = 'Dog'; color = 'Black'; gender = 'Female'; breed = 'Mixed' }|
    New-PodeOAExample -MediaType 'application/json' -Reference 'frog-example'
  )
```
```json
{
  "application/json": {
    "schema": {
         "$ref": "#/components/schemas/Pet"
    },
    "examples": {
      "cat" : {
        "summary": "An example of a cat",
        "value":
          {
            "name": "Fluffy",
            "petType": "Cat",
            "color": "White",
            "gender": "male",
            "breed": "Persian"
          }
      },
      "dog": {
        "summary": "An example of a dog with a cat's name",
        "value" :  {
          "name": "Puma",
          "petType": "Dog",
          "color": "Black",
          "gender": "Female",
          "breed": "Mixed"
        },
      "frog": {
          "$ref": "#/components/examples/frog-example"
        }
      }
    }
  }
}
```

```yaml
application/json:
  schema:
    $ref: "#/components/schemas/Pet"
  examples:
    cat:
      summary: An example of a cat
      value:
        name: Fluffy
        petType: Cat
        color: White
        gender: male
        breed: Persian
    dog:
      summary: An example of a dog with a cat's name
      value:
        name: Puma
        petType: Dog
        color: Black
        gender: Female
        breed: Mixed
    frog:
      $ref: "#/components/examples/frog-example"
```

##### Considerations for File Uploads

In contrast with the 2.0 specification, `file` input/output content in OpenAPI is described with the same semantics as any other schema type. Specifically:
```yaml
# content transferred with base64 encoding
schema:
  type: string
  format: base64
```

```yaml
# content transferred in binary (octet-stream):
schema:
  type: string
  format: binary
```

These examples apply to either input payloads of file uploads or response payloads.

A `requestBody` for submitting a file in a `POST` operation may look like the following example:
```powershell
 Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Content @{'application/octet-stream' = (New-PodeOAStringProperty -Format binary)})
```
```yaml
requestBody:
  content:
    application/octet-stream:
      schema:
        # a binary file of any type
        type: string
        format: binary
```

In addition, specific media types MAY be specified:
```powershell
 Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Content @{
  'image/jpeg' = (New-PodeOAStringProperty -Format binary)
  'image/png' = (New-PodeOAStringProperty -Format binary)
  })
```
or

```powershell
New-PodeOAContentMediaType -MediaType 'image/jpeg','image/png' -Content (New-PodeOAStringProperty -Format binary)
```
```yaml
# multiple, specific media types may be specified:
requestBody:
  content:
      # a binary file of type png or jpeg
    'image/jpeg':
      schema:
        type: string
        format: binary
    'image/png':
      schema:
        type: string
        format: binary
```

To upload multiple files, a `multipart` media type MUST be used:
```powershell
 Set-PodeOARequest -Properties -RequestBody (New-PodeOARequestBody -Content @{
  'multipart/form-data' = (New-PodeOAStringProperty -Name 'file' -Format binary -Array)
  })
```
```yaml
requestBody:
  content:
    multipart/form-data:
      schema:
        properties:
          # The property name 'file' will be used for all files.
          file:
            type: array
            items:
              type: string
              format: binary
```
Note the use of the `-Properties` Parameter without that the result is
```yaml
requestBody:
  content:
    multipart/form-data:
      schema:
        type: array
        items:
          type: string
          format: binary
```

##### Support for x-www-form-urlencoded Request Bodies

To submit content using form url encoding via [RFC1866](https://tools.ietf.org/html/rfc1866), the following
definition may be used:
```powershell
 Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Content @{
                      'application/x-www-form-urlencoded' = (New-PodeOAObjectProperty -Properties @(
                         (New-PodeOAStringProperty -name 'id' -format 'uuid'), (New-PodeOAObjectProperty -name 'address' -NoProperties)))
})
```
```yaml
requestBody:
  content:
    application/x-www-form-urlencoded:
      schema:
        type: object
        properties:
          id:
            type: string
            format: uuid
          address:
            # complex types are stringified to support RFC 1866
            type: object
            properties: {}
```


In this example, the contents in the `requestBody` MUST be stringified per [RFC1866](https://tools.ietf.org/html/rfc1866/) when passed to the server.  In addition, the `address` field complex object will be stringified.

When passing complex objects in the `application/x-www-form-urlencoded` content type, the default serialization strategy of such properties is described in the [`Encoding Object`](#encodingObject)'s [`style`](#encodingStyle) property as `form`.

##### Special Considerations for `multipart` Content

It is common to use `multipart/form-data` as a `Content-Type` when transferring request bodies to operations.  In contrast to 2.0, a `schema` is REQUIRED to define the input parameters to the operation when using `multipart` content.  This supports complex structures as well as supporting mechanisms for multiple file uploads.

When passing in `multipart` types, boundaries MAY be used to separate sections of the content being transferred — thus, the following default `Content-Type`s are defined for `multipart`:

* If the property is a primitive, or an array of primitive values, the default Content-Type is `text/plain`
* If the property is complex, or an array of complex values, the default Content-Type is `application/json`
* If the property is a `type: string` with `format: binary` or `format: base64` (aka a file object), the default Content-Type is `application/octet-stream`


Examples:
```powershell
 Set-PodeOARequest -RequestBody  (
  New-PodeOARequestBody -Content (
    New-PodeOAContentMediaType -MediaType 'multipart/form-data' -Content (
      New-PodeOAStringProperty -name 'id' -format 'uuid' |
          New-PodeOAObjectProperty -name 'address' -NoProperties |
          New-PodeOAStringProperty -name 'children' -array |
          New-PodeOASchemaProperty -Name 'addresses' -Reference 'Address' -Array |
          New-PodeOAObjectProperty
      )
    )
 )
```
```yaml
requestBody:
  content:
    multipart/form-data:
      schema:
        type: object
        properties:
          id:
            type: string
            format: uuid
          address:
            # default Content-Type for objects is `application/json`
            type: object
            properties: {}
          profileImage:
            # default Content-Type for string/binary is `application/octet-stream`
            type: string
            format: binary
          children:
            # default Content-Type for arrays is based on the `inner` type (text/plain here)
            type: array
            items:
              type: string
          addresses:
            # default Content-Type for arrays is based on the `inner` type (object shown, so `application/json` in this example)
            type: array
            items:
              type: '#/components/schemas/Address'
```

An `encoding` attribute is introduced to give you control over the serialization of parts of `multipart` request bodies.  This attribute is _only_ applicable to `multipart` and `application/x-www-form-urlencoded` request bodies.

#### <a name="encodingObject"></a>Encoding Object

A single encoding definition applied to a single schema property.

##### Fixed Fields
| Field Name                                        |                                         Type                                          | `New-PodeOAEncodingObject` | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------------------------- | :-----------------------------------------------------------------------------------: | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="encodingContentType"></a>contentType     |                                       `string`                                        | `-ContentType`             | The Content-Type for encoding a specific property. Default value depends on the property type: for `string` with `format` being `binary` – `application/octet-stream`; for other primitive types – `text/plain`; for `object` - `application/json`; for `array` – the default is defined based on the inner type. The value can be a specific media type (e.g. `application/json`), a wildcard media type (e.g. `image/*`), or a comma-separated list of the two types. |
| <a name="encodingHeaders"></a>headers             | Map[`string`, [Header Object](#headerObject) \| [Reference Object](#referenceObject)] | `-Headers`                 | A map allowing additional information to be provided as headers, for example `Content-Disposition`.  `Content-Type` is described separately and SHALL be ignored in this section. This property SHALL be ignored if the request body media type is not a `multipart`.                                                                                                                                                                                                   |
| <a name="encodingStyle"></a>style                 |                                       `string`                                        | `-Style`                   | Describes how a specific property value will be serialized depending on its type.  See [Parameter Object](#parameterObject) for details on the [`style`](#parameterStyle) property. The behavior follows the same values as `query` parameters, including default values. This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.                                                                                     |
| <a name="encodingExplode"></a>explode             |                                       `boolean`                                       | `-Explode`                 | When this is true, property values of type `array` or `object` generate separate parameters for each value of the array, or key-value-pair of the map.  For other types of properties this property has no effect. When [`style`](#encodingStyle) is `form`, the default value is `true`. For all other styles, the default value is `false`. This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.                 |
| <a name="encodingAllowReserved"></a>allowReserved |                                       `boolean`                                       | `-AllowReserved`           | Determines whether the parameter value SHOULD allow reserved characters, as defined by [RFC3986](https://tools.ietf.org/html/rfc3986#section-2.2) `:/?#[]@!$&'()*+,;=` to be included without percent-encoding. The default value is `false`. This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.                                                                                                                 |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Encoding Object Example

```powershell
New-PodeOARequestBody -Content (New-PodeOAContentMediaType -MediaType 'multipart/mixed' -Content (
                    New-PodeOAStringProperty -name 'id' -format 'uuid' |
                        New-PodeOAObjectProperty -name 'address' -NoProperties |
                        New-PodeOAObjectProperty -name 'historyMetadata' -Description 'metadata in XML format' -NoProperties |
                        New-PodeOAStringProperty -name 'profileImage' -Format Binary |
                        New-PodeOAObjectProperty
                    )) -Encoding (
                        New-PodeOAEncodingObject -Name 'historyMetadata' -ContentType 'application/xml; charset=utf-8' |
                            New-PodeOAEncodingObject -Name 'profileImage' -ContentType 'image/png, image/jpeg' -Headers (
                                New-PodeOAIntProperty -name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period'
                            )
                        )
```
```yaml
requestBody:
  content:
    multipart/mixed:
      schema:
        type: object
        properties:
          id:
            # default is text/plain
            type: string
            format: uuid
          address:
            # default is application/json
            type: object
            properties: {}
          historyMetadata:
            # need to declare XML format!
            description: metadata in XML format
            type: object
            properties: {}
          profileImage:
            # default is application/octet-stream, need to declare an image type only!
            type: string
            format: binary
      encoding:
        historyMetadata:
          # require XML Content-Type in utf-8 encoding
          contentType: application/xml; charset=utf-8
        profileImage:
          # only accept png/jpeg
          contentType: image/png, image/jpeg
          headers:
            X-Rate-Limit-Limit:
              description: The number of allowed requests in the current period
              schema:
                type: integer
```

#### <a name="responsesObject"></a>Responses Object

A container for the expected responses of an operation.
The container maps a HTTP response code to the expected response.

The documentation is not necessarily expected to cover all possible HTTP response codes because they may not be known in advance.
However, documentation is expected to cover a successful operation response and any known errors.

The `default` MAY be used as a default response object for all HTTP codes
that are not covered individually by the specification.

The `Responses Object` MUST contain at least one response code, and it
SHOULD be the response for a successful operation call.

##### Fixed Fields
| Field Name                             |                                    Type                                    | `Add-PodeOAResponse` | Description                                                                                                                                                                                                                                                                                       |
| -------------------------------------- | :------------------------------------------------------------------------: | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="responsesDefault"></a>default | [Response Object](#responseObject) \| [Reference Object](#referenceObject) | `-Default`           | The documentation of responses other than the ones declared for specific HTTP response codes. Use this field to cover undeclared responses. A [Reference Object](#referenceObject) can link to a response that the [OpenAPI Object's components/responses](#componentsResponses) section defines. |

##### Patterned Fields
| Field Pattern                                              |                                    Type                                    | `Add-PodeOAResponse` | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ---------------------------------------------------------- | :------------------------------------------------------------------------: | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="responsesCode"></a>[HTTP Status Code](#httpCodes) | [Response Object](#responseObject) \| [Reference Object](#referenceObject) | `-StatusCode`        | Any [HTTP status code](#httpCodes) can be used as the property name, but only one property per code, to describe the expected response for that HTTP status code.  A [Reference Object](#referenceObject) can link to a response that is defined in the [OpenAPI Object's components/responses](#componentsResponses) section. This field MUST be enclosed in quotation marks (for example, "200") for compatibility between JSON and YAML. To define a range of response codes, this field MAY contain the uppercase wildcard character `X`. For example, `2XX` represents all response codes between `[200-299]`. Only the following range definitions are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`. If a response is defined using an explicit code, the explicit code definition takes precedence over the range definition for that code. |


This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Responses Object Example

A 200 response for a successful operation and a default response for others (implying an error):
```powershell
Add-PodeOAResponse -StatusCode 200 -Description 'a pet to be returned' -Content (@{  'application/json' = 'Pet' }) -PassThru |
Add-PodeOAResponse -Default -Description 'Unexpected error' -Content (@{  'application/json' = 'ErrorModel' })
```
```json
{
  "200": {
    "description": "a pet to be returned",
    "content": {
      "application/json": {
        "schema": {
          "$ref": "#/components/schemas/Pet"
        }
      }
    }
  },
  "default": {
    "description": "Unexpected error",
    "content": {
      "application/json": {
        "schema": {
          "$ref": "#/components/schemas/ErrorModel"
        }
      }
    }
  }
}
```

```yaml
'200':
  description: a pet to be returned
  content:
    application/json:
      schema:
        $ref: '#/components/schemas/Pet'
default:
  description: Unexpected error
  content:
    application/json:
      schema:
        $ref: '#/components/schemas/ErrorModel'
```

#### <a name="responseObject"></a>Response Object
Describes a single response from an API Operation, including design-time, static
`links` to operations based on the response.

##### Fixed Fields
| Field Name                                    |                                          Type                                          | `Add-PodeOAResponse` | Description                                                                                                                                                                                                                                                                                                 |
| --------------------------------------------- | :------------------------------------------------------------------------------------: | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="responseDescription"></a>description |                                        `string`                                        | `-Description`       | **REQUIRED**. A short description of the response. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                              |
| <a name="responseHeaders"></a>headers         | Map[`string`, [Header Object](#headerObject)  \| [Reference Object](#referenceObject)] | `-Headers`           | Maps a header name to its definition. [RFC7230](https://tools.ietf.org/html/rfc7230#page-22) states header names are case insensitive. If a response header is defined with the name `"Content-Type"`, it SHALL be ignored.                                                                                 |
| <a name="responseContent"></a>content         |                  Map[`string`, [Media Type Object](#mediaTypeObject)]                  | `-Content`           | A map containing descriptions of potential response payloads. The key is a media type or [media type range](https://tools.ietf.org/html/rfc7231#appendix-D) and the value describes it.  For responses that match multiple keys, only the most specific key is applicable. e.g. text/plain overrides text/* |
| <a name="responseLinks"></a>links             |   Map[`string`, [Link Object](#linkObject) \| [Reference Object](#referenceObject)]    | TBD                  | A map of operations links that can be followed from the response. The key of the map is a short name for the link, following the naming constraints of the names for [Component Objects](#componentsObject).                                                                                                |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Response Object Examples

Response of an array of a complex type:
```powershell
Add-PodeOAResponse -StatusCode 200 -Description 'A complex object array response' -Content (
  New-PodeOAMediaContentType -MediaType 'application/json' -Content 'VeryComplexType'  -Array
)
```
```json
{
  "200": {
    "description": "A complex object array response",
    "content": {
      "application/json": {
        "schema": {
          "type": "array",
          "items": {
            "$ref": "#/components/schemas/VeryComplexType"
          }
        }
      }
    }
  }
}
```

```yaml
'200':
  description: A complex object array response
  content:
    application/json:
      schema:
        type: array
        items:
          $ref: '#/components/schemas/VeryComplexType'
```

Response with a string type:
```powershell
Add-PodeOAResponse -StatusCode 200 -Description 'A simple string response' -Content (New-PodeOAMediaContentType -MediaType 'text/plain' -Content (New-PodeOAStringProperty) -Array)
```
or
```powershell
Add-PodeOAResponse -StatusCode 200 -Description 'A simple string response' -Content (New-PodeOAMediaContentType -MediaType 'text/plain' -Content 'string' -Array)
```
```json
{
  "200": {
      "description": "A simple string response",
      "content": {
        "text/plain": {
          "schema": {
            "type": "string"
          }
        }
      }

    }
}
```

```yaml
'200':
  description: A simple string response
  content:
    text/plain:
      schema:
        type: string
```

Plain text response with headers:
```powershell
 Add-PodeOAResponse -StatusCode 200 -Description 'A simple string response' -Content @{
  'text/plain' = ( New-PodeOAStringProperty -Example 'whoa!')
  } -Headers (
              New-PodeOAIntProperty -Name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period' |
                  New-PodeOAIntProperty -Name 'X-Rate-Limit-Remaining' -Description 'The number of remaining requests in the current period' |
                  New-PodeOAIntProperty -Name 'X-Rate-Limit-Reset' -Description 'The number of seconds left in the current period'
              )
```
```json
{
  "200": {
    "description": "A simple string response",
    "content": {
      "text/plain": {
        "schema": {
          "type": "string",
          "example": "whoa!"
        }
      }
    },
    "headers": {
      "X-Rate-Limit-Limit": {
        "description": "The number of allowed requests in the current period",
        "schema": {
          "type": "integer"
        }
      },
      "X-Rate-Limit-Remaining": {
        "description": "The number of remaining requests in the current period",
        "schema": {
          "type": "integer"
        }
      },
      "X-Rate-Limit-Reset": {
        "description": "The number of seconds left in the current period",
        "schema": {
          "type": "integer"
        }
      }
    }
  }
}
```

```yaml
'200':
  description: A simple string response
  content:
    text/plain:
      schema:
        type: string
      example: 'whoa!'
  headers:
    X-Rate-Limit-Limit:
      description: The number of allowed requests in the current period
      schema:
        type: integer
    X-Rate-Limit-Remaining:
      description: The number of remaining requests in the current period
      schema:
        type: integer
    X-Rate-Limit-Reset:
      description: The number of seconds left in the current period
      schema:
        type: integer
```

Response with no return value:
```powershell
Add-PodeOAResponse -StatusCode 200 -Description 'object created'
```
```json
{
  "200": {
    "description": "object created"
  }
}
```

```yaml
'200':
  description: object created
```

#### <a name="callbackObject"></a>Callback Object

A map of possible out-of band callbacks related to the parent operation.
Each value in the map is a [Path Item Object](#pathItemObject) that describes a set of requests that may be initiated by the API provider and the expected responses.
The key value used to identify the path item object is an expression, evaluated at runtime, that identifies a URL to use for the callback operation.

##### Patterned Fields
| Field Pattern                                 |                Type                 | Description                                                                                                                                              |
| --------------------------------------------- | :---------------------------------: | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="callbackExpression"></a>{expression} | [Path Item Object](#pathItemObject) | A Path Item Object used to define a callback request and expected responses.  A [complete example](../examples/v3.0/callback-example.yaml) is available. |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Key Expression

The key that identifies the [Path Item Object](#pathItemObject) is a [runtime expression](#runtimeExpression) that can be evaluated in the context of a runtime HTTP request/response to identify the URL to be used for the callback request.
A simple example might be `$request.body#/url`.
However, using a [runtime expression](#runtimeExpression) the complete HTTP message can be accessed.
This includes accessing any part of a body that a JSON Pointer [RFC6901](https://tools.ietf.org/html/rfc6901) can reference.

For example, given the following HTTP request:

```http
POST /subscribe/myevent?queryUrl=http://clientdomain.com/stillrunning HTTP/1.1
Host: example.org
Content-Type: application/json
Content-Length: 187

{
  "failedUrl" : "http://clientdomain.com/failed",
  "successUrls" : [
    "http://clientdomain.com/fast",
    "http://clientdomain.com/medium",
    "http://clientdomain.com/slow"
  ]
}

201 Created
Location: http://example.org/subscription/1
```

The following examples show how the various expressions evaluate, assuming the callback operation has a path parameter named `eventType` and a query parameter named `queryUrl`.

| Expression                   | Value                                                                              |
| ---------------------------- | :--------------------------------------------------------------------------------- |
| $url                         | http://example.org/subscribe/myevent?queryUrl=http://clientdomain.com/stillrunning |
| $method                      | POST                                                                               |
| $request.path.eventType      | myevent                                                                            |
| $request.query.queryUrl      | http://clientdomain.com/stillrunning                                               |
| $request.header.content-Type | application/json                                                                   |
| $request.body#/failedUrl     | http://clientdomain.com/failed                                                     |
| $request.body#/successUrls/2 | http://clientdomain.com/medium                                                     |
| $response.header.Location    | http://example.org/subscription/1                                                  |


##### Callback Object Examples

The following example uses the user provided `queryUrl` query string parameter to define the callback URL.  This is an example of how to use a callback object to describe a WebHook callback that goes with the subscription operation to enable registering for the WebHook.
```powershell
Add-PodeOACallBacks -Title 'test' -Path '{$request.query.queryUrl}' -Method Post `
  -RequestBody (New-PodeOARequestBody -Description 'Callback payload' `
  -Content @{'application/json' = 'SomePayload' } ) `
  -Response ( Add-PodeOACallBacksResponse -StatusCode 200 -Description 'callback successfully processed' )
```
```yaml
myCallback:
  '{$request.query.queryUrl}':
    post:
      requestBody:
        description: Callback payload
        content:
          'application/json':
            schema:
              $ref: '#/components/schemas/SomePayload'
      responses:
        '200':
          description: callback successfully processed
```

The following example shows a callback where the server is hard-coded, but the query string parameters are populated from the `id` and `email` property in the request body.

```yaml
transactionCallback:
  'http://notificationServer.com?transactionId={$request.body#/id}&email={$request.body#/email}':
    post:
      requestBody:
        description: Callback payload
        content:
          'application/json':
            schema:
              $ref: '#/components/schemas/SomePayload'
      responses:
        '200':
          description: callback successfully processed
```

#### <a name="exampleObject"></a>Example Object

##### Fixed Fields
| Field Name                                       |   Type   | `New-PodeOAExample  ` | Description                                                                                                                                                                                                                                                |
| ------------------------------------------------ | :------: | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="exampleSummary"></a>summary             | `string` | `-Summary`            | Short description for the example.                                                                                                                                                                                                                         |
| <a name="exampleDescription"></a>description     | `string` | `-Description`        | Long description for the example. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                              |
| <a name="exampleValue"></a>value                 |   Any    | `-Value`              | Embedded literal example. The `value` field and `externalValue` field are mutually exclusive. To represent examples of media types that cannot naturally represented in JSON or YAML, use a string value to contain the example, escaping where necessary. |
| <a name="exampleExternalValue"></a>externalValue | `string` | `-ExternalValue`      | A URL that points to the literal example. This provides the capability to reference examples that cannot easily be included in JSON or YAML documents.  The `value` field and `externalValue` field are mutually exclusive.                                |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

In all cases, the example value is expected to be compatible with the type schema
of its associated value.  Tooling implementations MAY choose to
validate compatibility automatically, and reject the example value(s) if incompatible.

##### Example Object Examples

In a request body:
```powershell
New-PodeOARequestBody -Content @{ 'application/json' = 'Address' } -Examples (
  New-PodeOAExample -MediaType 'application/json' -Name 'foo' -Summary 'A foo example' -Value  @{foo = 'bar' } |
    New-PodeOAExample -MediaType 'application/json' -Name 'bar' -Summary 'A bar example' -Value @{'bar' = 'baz' }|
    New-PodeOAExample -MediaType 'application/xml' -Name 'xmlExample' -Summary 'This is an example in XML' -ExternalValue 'http://example.org/examples/address-example.xml' |
    New-PodeOAExample -MediaType 'text/plain' -Name 'textExample' -Summary 'This is an example' -ExternalValue 'http://example.org/examples/address-example.txt' |
  )
```
```yaml
requestBody:
  content:
    'application/json':
      schema:
        $ref: '#/components/schemas/Address'
      examples:
        foo:
          summary: A foo example
          value: {"foo": "bar"}
        bar:
          summary: A bar example
          value: {"bar": "baz"}
    'application/xml':
      examples:
        xmlExample:
          summary: This is an example in XML
          externalValue: 'http://example.org/examples/address-example.xml'
    'text/plain':
      examples:
        textExample:
          summary: This is a text example
          externalValue: 'http://foo.bar/examples/address-example.txt'
```

In a parameter:
```powershell
New-PodeOAStringProperty -Name 'zipCode' -format 'zip-code' |
  ConvertTo-PodeOAParameter -In Query -Examples (
    New-PodeOAExample   -Name 'zip-example' -Refence 'zip-example'
  )
```
```yaml
parameters:
  - name: 'zipCode'
    in: 'query'
    schema:
      type: 'string'
      format: 'zip-code'
    examples:
      zip-example:
        $ref: '#/components/examples/zip-example'
```

In a response:

```yaml
responses:
  '200':
    description: your car appointment has been booked
    content:
      application/json:
        schema:
          $ref: '#/components/schemas/SuccessResponse'
        examples:
          confirmation-success:
            $ref: '#/components/examples/confirmation-success'
```


#### <a name="linkObject"></a>Link Object

The `Link object` represents a possible design-time link for a response.
The presence of a link does not guarantee the caller's ability to successfully invoke it, rather it provides a known relationship and traversal mechanism between responses and other operations.

Unlike _dynamic_ links (i.e. links provided **in** the response payload), the OAS linking mechanism does not require link information in the runtime response.

For computing links, and providing instructions to execute them, a [runtime expression](#runtimeExpression) is used for accessing values in an operation and using them as parameters while invoking the linked operation.

##### Fixed Fields

| Field Name                                  |                           Type                           | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------- | :------------------------------------------------------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="linkOperationRef"></a>operationRef |                         `string`                         | A relative or absolute URI reference to an OAS operation. This field is mutually exclusive of the `operationId` field, and MUST point to an [Operation Object](#operationObject). Relative `operationRef` values MAY be used to locate an existing [Operation Object](#operationObject) in the OpenAPI definition.                                                                                                                                                  |
| <a name="linkOperationId"></a>operationId   |                         `string`                         | The name of an _existing_, resolvable OAS operation, as defined with a unique `operationId`.  This field is mutually exclusive of the `operationRef` field.                                                                                                                                                                                                                                                                                                         |
| <a name="linkParameters"></a>parameters     | Map[`string`, Any \| [{expression}](#runtimeExpression)] | A map representing parameters to pass to an operation as specified with `operationId` or identified via `operationRef`. The key is the parameter name to be used, whereas the value can be a constant or an expression to be evaluated and passed to the linked operation.  The parameter name can be qualified using the [parameter location](#parameterIn) `[{in}.]{name}` for operations that use the same parameter name in different locations (e.g. path.id). |
| <a name="linkRequestBody"></a>requestBody   |        Any \| [{expression}](#runtimeExpression)         | A literal value or [{expression}](#runtimeExpression) to use as a request body when calling the target operation.                                                                                                                                                                                                                                                                                                                                                   |
| <a name="linkDescription"></a>description   |                         `string`                         | A description of the link. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                                                                                                                                                                                              |
| <a name="linkServer"></a>server             |              [Server Object](#serverObject)              | A server object to be used by the target operation.                                                                                                                                                                                                                                                                                                                                                                                                                 |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

A linked operation MUST be identified using either an `operationRef` or `operationId`.
In the case of an `operationId`, it MUST be unique and resolved in the scope of the OAS document.
Because of the potential for name clashes, the `operationRef` syntax is preferred
for specifications with external references.

##### Examples

Computing a link from a request operation where the `$request.path.id` is used to pass a request parameter to the linked operation.

```yaml
paths:
  /users/{id}:
    parameters:
    - name: id
      in: path
      required: true
      description: the user identifier, as userId
      schema:
        type: string
    get:
      responses:
        '200':
          description: the user being returned
          content:
            application/json:
              schema:
                type: object
                properties:
                  uuid: # the unique user id
                    type: string
                    format: uuid
          links:
            address:
              # the target link operationId
              operationId: getUserAddress
              parameters:
                # get the `id` field from the request path parameter named `id`
                userId: $request.path.id
  # the path item of the linked operation
  /users/{userid}/address:
    parameters:
    - name: userid
      in: path
      required: true
      description: the user identifier, as userId
      schema:
        type: string
    # linked operation
    get:
      operationId: getUserAddress
      responses:
        '200':
          description: the user's address
```

When a runtime expression fails to evaluate, no parameter value is passed to the target operation.

Values from the response body can be used to drive a linked operation.

```yaml
links:
  address:
    operationId: getUserAddressByUUID
    parameters:
      # get the `uuid` field from the `uuid` field in the response body
      userUuid: $response.body#/uuid
```

Clients follow all links at their discretion.
Neither permissions, nor the capability to make a successful call to that link, is guaranteed
solely by the existence of a relationship.


##### OperationRef Examples

As references to `operationId` MAY NOT be possible (the `operationId` is an optional
field in an [Operation Object](#operationObject)), references MAY also be made through a relative `operationRef`:

```yaml
links:
  UserRepositories:
    # returns array of '#/components/schemas/repository'
    operationRef: '#/paths/~12.0~1repositories~1{username}/get'
    parameters:
      username: $response.body#/username
```

or an absolute `operationRef`:

```yaml
links:
  UserRepositories:
    # returns array of '#/components/schemas/repository'
    operationRef: 'https://na2.gigantic-server.com/#/paths/~12.0~1repositories~1{username}/get'
    parameters:
      username: $response.body#/username
```

Note that in the use of `operationRef`, the _escaped forward-slash_ is necessary when
using JSON references.


##### <a name="runtimeExpression"></a>Runtime Expressions

Runtime expressions allow defining values based on information that will only be available within the HTTP message in an actual API call.
This mechanism is used by [Link Objects](#linkObject) and [Callback Objects](#callbackObject).

The runtime expression is defined by the following [ABNF](https://tools.ietf.org/html/rfc5234) syntax

```abnf
      expression = ( "$url" / "$method" / "$statusCode" / "$request." source / "$response." source )
      source = ( header-reference / query-reference / path-reference / body-reference )
      header-reference = "header." token
      query-reference = "query." name
      path-reference = "path." name
      body-reference = "body" ["#" json-pointer ]
      json-pointer    = *( "/" reference-token )
      reference-token = *( unescaped / escaped )
      unescaped       = %x00-2E / %x30-7D / %x7F-10FFFF
         ; %x2F ('/') and %x7E ('~') are excluded from 'unescaped'
      escaped         = "~" ( "0" / "1" )
        ; representing '~' and '/', respectively
      name = *( CHAR )
      token = 1*tchar
      tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." /
        "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
```

Here, `json-pointer` is taken from [RFC 6901](https://tools.ietf.org/html/rfc6901), `char` from [RFC 7159](https://tools.ietf.org/html/rfc7159#section-7) and `token` from [RFC 7230](https://tools.ietf.org/html/rfc7230#section-3.2.6).

The `name` identifier is case-sensitive, whereas `token` is not.

The table below provides examples of runtime expressions and examples of their use in a value:

##### <a name="runtimeExpressionExamples"></a>Examples

| Source Location       | example expression         | notes                                                                                                                                               |
| --------------------- | :------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP Method           | `$method`                  | The allowable values for the `$method` will be those for the HTTP operation.                                                                        |
| Requested media type  | `$request.header.accept`   |
| Request parameter     | `$request.path.id`         | Request parameters MUST be declared in the `parameters` section of the parent operation or they cannot be evaluated. This includes request headers. |
| Request body property | `$request.body#/user/uuid` | In operations which accept payloads, references may be made to portions of the `requestBody` or the entire body.                                    |
| Request URL           | `$url`                     |
| Response value        | `$response.body#/status`   | In operations which return payloads, references may be made to portions of the response body or the entire body.                                    |
| Response header       | `$response.header.Server`  | Single header values only are available                                                                                                             |

Runtime expressions preserve the type of the referenced value.
Expressions can be embedded into string values by surrounding the expression with `{}` curly braces.

#### <a name="headerObject"></a>Header Object

The Header Object follows the structure of the [Parameter Object](#parameterObject) with the following changes:

1. `name` MUST NOT be specified, it is given in the corresponding `headers` map.
1. `in` MUST NOT be specified, it is implicitly in `header`.
1. All traits that are affected by the location MUST be applicable to a location of `header` (for example, [`style`](#parameterStyle)).

##### Header Object Example

A simple header of type `integer`:

```json
{
  "description": "The number of allowed requests in the current period",
  "schema": {
    "type": "integer"
  }
}
```

```yaml
description: The number of allowed requests in the current period
schema:
  type: integer
```

#### <a name="tagObject"></a>Tag Object

Adds metadata to a single tag that is used by the [Operation Object](#operationObject).
It is not mandatory to have a Tag Object per tag defined in the Operation Object instances.

##### Fixed Fields
| Field Name                                 |                             Type                              | `Add-PodeOATag` | Description                                                                                                                         |
| ------------------------------------------ | :-----------------------------------------------------------: | --------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| <a name="tagName"></a>name                 |                           `string`                            | `-Name`         | **REQUIRED**. The name of the tag.                                                                                                  |
| <a name="tagDescription"></a>description   |                           `string`                            | `-Description`  | A short description for the tag. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.        |
| <a name="tagExternalDocs"></a>externalDocs | [External Documentation Object](#externalDocumentationObject) | `-ExternalDocs` | Additional external documentation for this tag.  In Pode is a reference to  ExternalDoc object created with `New-PodeOAExternalDoc` |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Tag Object Example
```powershell
 Add-PodeOATag -Name 'pet' -Description 'Pets operations'
```
```json
{
	"name": "pet",
	"description": "Pets operations"
}
```

```yaml
name: pet
description: Pets operations
```


#### <a name="referenceObject"></a>Reference Object

A simple object to allow referencing other components in the specification, internally and externally.

The Reference Object is defined by [JSON Reference](https://tools.ietf.org/html/draft-pbryan-zyp-json-ref-03) and follows the same structure, behavior and rules.

For this specification, reference resolution is accomplished as defined by the JSON Reference specification and not by the JSON Schema specification.

##### Fixed Fields
| Field Name                      |   Type   | Description                         |
| ------------------------------- | :------: | ----------------------------------- |
| <a name="referenceRef"></a>$ref | `string` | **REQUIRED**. The reference string. |

This object cannot be extended with additional properties and any properties added SHALL be ignored.

Multiple cmdlets support `$ref` : `Merge-PodeOAProperty`, `New-PodeOASchemaProperty`, `Add-PodeOAResponse`, `New-PodeOAResponse` `New-PodeOARequestBody`
##### Reference Object Example
```powershell
New-PodeOASchemaProperty -Name 'something' -Reference 'Pet'
```
```powershell
Merge-PodeOAProperty -Type AllOf -ObjectDefinitions 'Pet','Animal'
```
```powershell
Add-PodeOAResponse -Default -Content (New-PodeOAMediaContentType -Content 'Pet')
```

```powershell
New-PodeOAResponse -Default -Content (New-PodeOAMediaContentType -Content 'Pet')
```
```powershell
New-PodeOAComponentResponse -Name 'Pet' -Default -Content (New-PodeOAMediaContentType -Content 'Pet')
```
```json
{
	"$ref": "#/components/schemas/Pet"
}
```

```yaml
$ref: '#/components/schemas/Pet'
```

##### Relative Schema Document Example
```json
{
  "$ref": "Pet.json"
}
```

```yaml
$ref: Pet.yaml
```

##### Relative Documents With Embedded Schema Example
```json
{
  "$ref": "definitions.json#/Pet"
}
```

```yaml
$ref: definitions.yaml#/Pet
```

#### <a name="schemaObject"></a>Schema Object

The Schema Object allows the definition of input and output data types.
These types can be objects, but also primitives and arrays.
This object is an extended subset of the [JSON Schema Specification Wright Draft 00](https://json-schema.org/).

For more information about the properties, see [JSON Schema Core](https://tools.ietf.org/html/draft-wright-json-schema-00) and [JSON Schema Validation](https://tools.ietf.org/html/draft-wright-json-schema-validation-00).
Unless stated otherwise, the property definitions follow the JSON Schema.

##### Properties

The following properties are taken directly from the JSON Schema definition and follow the same specifications:

type - Value MUST be a string. Multiple types via an array are not supported.

| type   | cmdlet                     |
| ------ | -------------------------- |
| int    | `New-PodeOAIntProperty`    |
| string | `New-PodeOAStringProperty` |
| object | `New-PodeOAObjectProperty` |
| bool   | `New-PodeOABoolProperty`   |
| number | `New-PodeOANumberProperty` |
|        |                            |

| Field Name       | `New-PodeOAIntProperty` \| `New-PodeOAStringProperty` \| `New-PodeOAObjectProperty` \| `New-PodeOABoolProperty` \| `New-PodeOANumberProperty` | Description                                                                                                                                                                                                                                                                                                                             |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| title            | `-Name`  or `-Title`                                                                                                                          |
| multipleOf       | `-MultipleOf`                                                                                                                                 | `New-PodeOANumberProperty` \| `New-PodeOAIntProperty`                                                                                                                                                                                                                                                                                   |
| maximum          | `-Maximum`                                                                                                                                    | `New-PodeOANumberProperty` \| `New-PodeOAIntProperty`                                                                                                                                                                                                                                                                                   |
| exclusiveMaximum | `-ExclusiveMaximum`                                                                                                                           | `New-PodeOANumberProperty` \| `New-PodeOAIntProperty`                                                                                                                                                                                                                                                                                   |
| minimum          | `-Minimum`                                                                                                                                    | `New-PodeOANumberProperty` \| `New-PodeOAIntProperty`                                                                                                                                                                                                                                                                                   |
| exclusiveMinimum | `-ExclusiveMinimum`                                                                                                                           | `New-PodeOANumberProperty` \| `New-PodeOAIntProperty`                                                                                                                                                                                                                                                                                   |
| maxLength        | `-MaxLength`                                                                                                                                  | `New-PodeOAStringProperty`                                                                                                                                                                                                                                                                                                              |
| minLength        | `-MinLength`                                                                                                                                  | `New-PodeOAStringProperty`                                                                                                                                                                                                                                                                                                              |
| pattern          | `-Pattern`                                                                                                                                    | `New-PodeOAStringProperty` - (This string SHOULD be a valid regular expression, according to the [Ecma-262 Edition 5.1 regular expression](https://www.ecma-international.org/ecma-262/5.1/#sec-15.10.1) dialect)                                                                                                                       |
| maxItems         | `-MaxItems`                                                                                                                                   | Used in combination with `-Array` with any New-PodeOAxxxProperty cmdlet                                                                                                                                                                                                                                                                 |
| minItems         | `-MinItems`                                                                                                                                   | Used in combination with `-Array` with any New-PodeOAxxxProperty cmdlet                                                                                                                                                                                                                                                                 |
| uniqueItems      | `-UniqueItems`                                                                                                                                | Used in combination with `-Array` with any New-PodeOAxxxProperty cmdlet                                                                                                                                                                                                                                                                 |
| maxProperties    | `-MaxProperties`                                                                                                                              | `New-PodeOAObjectProperty`                                                                                                                                                                                                                                                                                                              |
| minProperties    | `-MinProperties`                                                                                                                              | `New-PodeOAObjectProperty`                                                                                                                                                                                                                                                                                                              |
| required         | `-Required`                                                                                                                                   | `New-PodeOAIntProperty` \| `New-PodeOAStringProperty`  \| `New-PodeOABoolProperty` \| `New-PodeOANumberProperty` \| `New-PodeOAObjectProperty`                                                                                                                                                                                          |
| enum             | `-Enum`                                                                                                                                       | `New-PodeOAIntProperty` \| `New-PodeOAStringProperty`  \| `New-PodeOABoolProperty` \| `New-PodeOANumberProperty` \| `New-PodeOAObjectProperty`                                                                                                                                                                                          |
| items            | `-Array`                                                                                                                                      | `New-PodeOAIntProperty` \| `New-PodeOAStringProperty`  \| `New-PodeOABoolProperty` \| `New-PodeOANumberProperty` \| `New-PodeOAObjectProperty`                                                                                                                                                                                          |
| description      | `-Description`                                                                                                                                | [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                                                                                             |
| default          | `-Default`                                                                                                                                    | The default value represents what would be assumed by the consumer of the input as the value of the schema if one is not provided. Unlike JSON Schema, the value MUST conform to the defined type for the Schema Object defined at the same level. For example, if `type` is `string`, then `default` can be `"foo"` but cannot be `1`. |
| properties       | `-properties`                                                                                                                                 | `New-PodeOAObjectProperty`  Property definitions MUST be a [Schema Object](#schemaObject) and not a standard JSON Schema (inline or referenced).                                                                                                                                                                                        |

| type                                            | `Merge-PodeOAProperty` | Note                                                                                                                                                                                                                                                                                     |
| ----------------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| allOf                                           | `-Type AllOf`          |                                                                                                                                                                                                                                                                                          |
| oneOf                                           | `-Type OneOf`          | (Pode) Doesn't support schema validation                                                                                                                                                                                                                                                 |
| anyOf                                           | `-Type AnyOf`          | (Pode)Doesn't support schema validation                                                                                                                                                                                                                                                  |
| not                                             | Not supported          | Will be supported in a future release                                                                                                                                                                                                                                                    |
| <a name="schemaDiscriminator"></a>discriminator | `-Discriminator`       | [Discriminator Object](#discriminatorObject) - Adds support for polymorphism. The discriminator is an object name that is used to differentiate between other schemas which may satisfy the payload description. See [Composition and Inheritance](#schemaComposition) for more details. |





- additionalProperties - Value can be boolean or object. Inline or referenced schema MUST be of a [Schema Object](#schemaObject) and not a standard JSON Schema. Consistent with JSON Schema, `additionalProperties` defaults to `true`.
- format - See [Data Type Formats](#dataTypeFormat) for further details. While relying on JSON Schema's defined formats, the OAS offers a few additional predefined formats.


Alternatively, any time a Schema Object can be used, a [Reference Object](#referenceObject) can be used in its place. This allows referencing definitions instead of defining them inline.

Additional properties defined by the JSON Schema specification that are not mentioned here are strictly unsupported.

Other than the JSON Schema subset fields, the following fields MAY be used for further schema documentation:

##### Fixed Fields
| Field Name                                    |                             Type                              |                 | Description                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| --------------------------------------------- | :-----------------------------------------------------------: | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="schemaNullable"></a>nullable         |                           `boolean`                           | `-Nullable`     | A `true` value adds `"null"` to the allowed type specified by the `type` keyword, only if `type` is explicitly defined within the same Schema Object. Other Schema Object constraints retain their defined behavior, and therefore may disallow the use of `null` as a value. A `false` value leaves the specified or default `type` unmodified. The default value is `false`.                                                                    |
| <a name="schemaReadOnly"></a>readOnly         |                           `boolean`                           | `-ReadOnly`     | Relevant only for Schema `"properties"` definitions. Declares the property as "read only". This means that it MAY be sent as part of a response but SHOULD NOT be sent as part of the request. If the property is marked as `readOnly` being `true` and is in the `required` list, the `required` will take effect on the response only. A property MUST NOT be marked as both `readOnly` and `writeOnly` being `true`. Default value is `false`. |
| <a name="schemaWriteOnly"></a>writeOnly       |                           `boolean`                           | `-WriteOnly`    | Relevant only for Schema `"properties"` definitions. Declares the property as "write only". Therefore, it MAY be sent as part of a request but SHOULD NOT be sent as part of the response. If the property is marked as `writeOnly` being `true` and is in the `required` list, the `required` will take effect on the request only. A property MUST NOT be marked as both `readOnly` and `writeOnly` being `true`. Default value is `false`.     |
| <a name="schemaXml"></a>xml                   |                   [XML Object](#xmlObject)                    | `-Xml`          | This MAY be used only on properties schemas. It has no effect on root schemas. Adds additional metadata to describe the XML representation of this property.                                                                                                                                                                                                                                                                                      |
| <a name="schemaExternalDocs"></a>externalDocs | [External Documentation Object](#externalDocumentationObject) | `-ExternalDocs` | Additional external documentation for this schema.                                                                                                                                                                                                                                                                                                                                                                                                |
| <a name="schemaExample"></a>example           |                              Any                              | `-Example`      | A free-form property to include an example of an instance for this schema. To represent examples that cannot be naturally represented in JSON or YAML, a string value can be used to contain the example with escaping where necessary.                                                                                                                                                                                                           |
| <a name="schemaDeprecated"></a> deprecated    |                           `boolean`                           | `-Deprecated`   | Specifies that a schema is deprecated and SHOULD be transitioned out of usage. Default value is `false`.                                                                                                                                                                                                                                                                                                                                          |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

###### <a name="schemaComposition"></a>Composition and Inheritance (Polymorphism)

The OpenAPI Specification allows combining and extending model definitions using the `allOf` property of JSON Schema, in effect offering model composition.
`allOf` takes an array of object definitions that are validated *independently* but together compose a single object.

While composition offers model extensibility, it does not imply a hierarchy between the models.
To support polymorphism, the OpenAPI Specification adds the `discriminator` field.
When used, the `discriminator` will be the name of the property that decides which schema definition validates the structure of the model.
As such, the `discriminator` field MUST be a required field.
There are two ways to define the value of a discriminator for an inheriting instance.
- Use the schema name.
- Override the schema name by overriding the property with a new value. If a new value exists, this takes precedence over the schema name.
As such, inline schema definitions, which do not have a given id, *cannot* be used in polymorphism.

###### XML Modeling

The [xml](#schemaXml) property allows extra definitions when translating the JSON definition to XML.
The [XML Object](#xmlObject) contains additional information about the available options.

##### Schema Object Examples

###### Primitive Sample

```powershell
New-PodeOAStringProperty -Format 'email'
```

```json
{
  "type": "string",
  "format": "email"
}
```

```yaml
type: string
format: email
```

###### Simple Model
```powershell
New-PodeOAStringProperty -Name 'name'| New-PodeOASchemaProperty -Name 'Address' -Reference 'Address'|
  New-PodeOAIntProperty -Name 'age' -Minimum 0 -Format Int32 | New-PodeOAObjectProperty
```
```json
{
  "type": "object",
  "required": [
    "name"
  ],
  "properties": {
    "name": {
      "type": "string"
    },
    "address": {
      "$ref": "#/components/schemas/Address"
    },
    "age": {
      "type": "integer",
      "format": "int32",
      "minimum": 0
    }
  }
}
```

```yaml
type: object
required:
- name
properties:
  name:
    type: string
  address:
    $ref: '#/components/schemas/Address'
  age:
    type: integer
    format: int32
    minimum: 0
```

###### Model with Map/Dictionary Properties

For a simple string to string mapping:
```powershell
New-PodeOAObjectProperty -AdditionalProperties (New-PodeOAStringProperty )
```
```json
{
  "type": "object",
  "additionalProperties": {
    "type": "string"
  }
}
```

```yaml
type: object
additionalProperties:
  type: string
```

For a string to model mapping:
```powershell
New-PodeOAObjectProperty -AdditionalProperties (New-PodeOASchemaProperty  -Reference 'ComplexModel')
```
```json
{
  "type": "object",
  "additionalProperties": {
    "$ref": "#/components/schemas/ComplexModel"
  }
}
```

```yaml
type: object
additionalProperties:
  $ref: '#/components/schemas/ComplexModel'
```

###### Model with Example
```powershell
New-PodeOAIntProperty -Name 'id' -Format Int64 | New-PodeOAStringProperty -Name 'name'  -Required |
    New-PodeOAObjectProperty -Example @{"name"= "Puma"; "id"= 1}
```
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "integer",
      "format": "int64"
    },
    "name": {
      "type": "string"
    }
  },
  "required": [
    "name"
  ],
  "example": {
    "name": "Puma",
    "id": 1
  }
}
```

```yaml
type: object
properties:
  id:
    type: integer
    format: int64
  name:
    type: string
required:
- name
example:
  name: Puma
  id: 1
```

###### Models with Composition
```powershell
#Define ErrorModel schema
New-PodeOAStringProperty -Name 'message'  |
  New-PodeOAIntProperty -Name 'code' -Minimum 100 -Maximum 600 |
  New-PodeOAObjectProperty |
  Add-PodeOAComponentSchema -Name 'ErrorModel'

#Define ExtendedErrorModel schema
Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions 'ErrorModel', (New-PodeOAStringProperty -Name 'rootCause' -required -object) |
  Add-PodeOAComponentSchema -Name 'ExtendedErrorModel'
```
```json
{
  "components": {
    "schemas": {
      "ErrorModel": {
        "type": "object",
        "required": [
          "message",
          "code"
        ],
        "properties": {
          "message": {
            "type": "string"
          },
          "code": {
            "type": "integer",
            "minimum": 100,
            "maximum": 600
          }
        }
      },
      "ExtendedErrorModel": {
        "allOf": [
          {
            "$ref": "#/components/schemas/ErrorModel"
          },
          {
            "type": "object",
            "required": [
              "rootCause"
            ],
            "properties": {
              "rootCause": {
                "type": "string"
              }
            }
          }
        ]
      }
    }
  }
}
```

```yaml
components:
  schemas:
    ErrorModel:
      type: object
      required:
      - message
      - code
      properties:
        message:
          type: string
        code:
          type: integer
          minimum: 100
          maximum: 600
    ExtendedErrorModel:
      allOf:
      - $ref: '#/components/schemas/ErrorModel'
      - type: object
        required:
        - rootCause
        properties:
          rootCause:
            type: string
```

###### Models with Polymorphism Support
```powershell
#Define Pet schema
New-PodeOAStringProperty -Name 'name'| New-PodeOAStringProperty -Name 'petType' |
  New-PodeOAObjectProperty -DiscriminatorProperty 'petType' | Add-PodeOAComponentSchema -Name 'Pet'

#Define Cat schema
Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions 'Pet',
(New-PodeOAStringProperty -Name 'huntingSkill'  -Description "The measured skill for hunting" -Default "lazy" -Enum "clueless", "lazy", "adventurous", "aggressive" -Required -Object ) |
  Add-PodeOAComponentSchema -Name 'Cat' -Description "A representation of a cat. Note that `Cat` will be used as the discriminator value."


#Define Dog schema
Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions 'Pet',
(New-PodeOAIntProperty -Name 'packSize'  -Description "the size of the pack the dog is from" -Default 0 -Minimum 0 -Format Int32 -Required -Object ) |
  Add-PodeOAComponentSchema -Name 'Dog' -Description "A representation of a dog. Note that `Dog` will be used as the discriminator value."

```
```json
{
  "components": {
    "schemas": {
      "Pet": {
        "type": "object",
        "discriminator": {
          "propertyName": "petType"
        },
        "properties": {
          "name": {
            "type": "string"
          },
          "petType": {
            "type": "string"
          }
        },
        "required": [
          "name",
          "petType"
        ]
      },
      "Cat": {
        "description": "A representation of a cat. Note that `Cat` will be used as the discriminator value.",
        "allOf": [
          {
            "$ref": "#/components/schemas/Pet"
          },
          {
            "type": "object",
            "properties": {
              "huntingSkill": {
                "type": "string",
                "description": "The measured skill for hunting",
                "default": "lazy",
                "enum": [
                  "clueless",
                  "lazy",
                  "adventurous",
                  "aggressive"
                ]
              }
            },
            "required": [
              "huntingSkill"
            ]
          }
        ]
      },
      "Dog": {
        "description": "A representation of a dog. Note that `Dog` will be used as the discriminator value.",
        "allOf": [
          {
            "$ref": "#/components/schemas/Pet"
          },
          {
            "type": "object",
            "properties": {
              "packSize": {
                "type": "integer",
                "format": "int32",
                "description": "the size of the pack the dog is from",
                "default": 0,
                "minimum": 0
              }
            },
            "required": [
              "packSize"
            ]
          }
        ]
      }
    }
  }
}
```

```yaml
components:
  schemas:
    Pet:
      type: object
      discriminator:
        propertyName: petType
      properties:
        name:
          type: string
        petType:
          type: string
      required:
      - name
      - petType
    Cat:  ## "Cat" will be used as the discriminator value
      description: A representation of a cat
      allOf:
      - $ref: '#/components/schemas/Pet'
      - type: object
        properties:
          huntingSkill:
            type: string
            description: The measured skill for hunting
            enum:
            - clueless
            - lazy
            - adventurous
            - aggressive
        required:
        - huntingSkill
    Dog:  ## "Dog" will be used as the discriminator value
      description: A representation of a dog
      allOf:
      - $ref: '#/components/schemas/Pet'
      - type: object
        properties:
          packSize:
            type: integer
            format: int32
            description: the size of the pack the dog is from
            default: 0
            minimum: 0
        required:
        - packSize
```

#### <a name="discriminatorObject"></a>Discriminator Object

When request bodies or response payloads may be one of a number of different schemas, a `discriminator` object can be used to aid in serialization, deserialization, and validation.  The discriminator is a specific object in a schema which is used to inform the consumer of the specification of an alternative schema based on the value associated with it.

When using the discriminator, _inline_ schemas will not be considered.

##### Fixed Fields
| Field Name                                  |          Type           | `New-PodeOAObjectProperty` | Description                                                                                   |
| ------------------------------------------- | :---------------------: | -------------------------- | --------------------------------------------------------------------------------------------- |
| <a name="propertyName"></a>propertyName     |        `string`         | `-DiscriminatorProperty`   | **REQUIRED**. The name of the property in the payload that will hold the discriminator value. |
| <a name="discriminatorMapping"></a> mapping | Map[`string`, `string`] | `-DiscriminatorMapping`    | An object to hold mappings between payload values and schema names or references.             |

The discriminator object is legal only when using one of the composite keywords `oneOf`, `anyOf`, `allOf`.

In OAS 3.0, a response payload MAY be described to be exactly one of any number of types:
```powershell
Merge-PodeOAProperty  -Type OneOf -ObjectDefinitions 'Cat','Dog','Lizard'
```
```yaml
MyResponseType:
  oneOf:
  - $ref: '#/components/schemas/Cat'
  - $ref: '#/components/schemas/Dog'
  - $ref: '#/components/schemas/Lizard'
```

which means the payload _MUST_, by validation, match exactly one of the schemas described by `Cat`, `Dog`, or `Lizard`.  In this case, a discriminator MAY act as a "hint" to shortcut validation and selection of the matching schema which may be a costly operation, depending on the complexity of the schema. We can then describe exactly which field tells us which schema to use:

```powershell
Merge-PodeOAProperty  -Type OneOf -ObjectDefinitions 'Cat','Dog','Lizard' -DiscriminatorProperty 'petType'
```
```yaml
MyResponseType:
  oneOf:
  - $ref: '#/components/schemas/Cat'
  - $ref: '#/components/schemas/Dog'
  - $ref: '#/components/schemas/Lizard'
  discriminator:
    propertyName: petType
```

The expectation now is that a property with name `petType` _MUST_ be present in the response payload, and the value will correspond to the name of a schema defined in the OAS document.  Thus the response payload:

```json
{
  "id": 12345,
  "petType": "Cat"
}
```

Will indicate that the `Cat` schema be used in conjunction with this payload.

In scenarios where the value of the discriminator field does not match the schema name or implicit mapping is not possible, an optional `mapping` definition MAY be used:
```powershell
Merge-PodeOAProperty  -Type OneOf -ObjectDefinitions 'Cat','Dog','Lizard' `
  -DiscriminatorProperty 'petType' -DiscriminatorMapping @{
                                        'dog' = '#/components/schemas/Dog'
                                        'monster' = 'https://gigantic-server.com/schemas/Monster/schema.json'
                                        }
```
```yaml
MyResponseType:
  oneOf:
  - $ref: '#/components/schemas/Cat'
  - $ref: '#/components/schemas/Dog'
  - $ref: '#/components/schemas/Lizard'
  - $ref: 'https://gigantic-server.com/schemas/Monster/schema.json'
  discriminator:
    propertyName: petType
    mapping:
      dog: '#/components/schemas/Dog'
      monster: 'https://gigantic-server.com/schemas/Monster/schema.json'
```

Here the discriminator _value_ of `dog` will map to the schema `#/components/schemas/Dog`, rather than the default (implicit) value of `Dog`.  If the discriminator _value_ does not match an implicit or explicit mapping, no schema can be determined and validation SHOULD fail. Mapping keys MUST be string values, but tooling MAY convert response values to strings for comparison.

When used in conjunction with the `anyOf` construct, the use of the discriminator can avoid ambiguity where multiple schemas may satisfy a single payload.

In both the `oneOf` and `anyOf` use cases, all possible schemas MUST be listed explicitly.  To avoid redundancy, the discriminator MAY be added to a parent schema definition, and all schemas comprising the parent schema in an `allOf` construct may be used as an alternate schema.

For example:
```powershell

New-PodeOAStringProperty -Name 'petType' -Required  |New-PodeOAObjectProperty -DiscriminatorProperty 'petType' -DiscriminatorMapping @{ 'dog'='Dog'} |
  Add-PodeOAComponentSchema -Name 'Pet'

Merge-PodeOAProperty  -Name -Type AllOf -ObjectDefinitions 'Pet', ( New-PodeOAStringProperty  -Name 'name' -Object) |
  Add-PodeOAComponentSchema -Name 'Cat'

Merge-PodeOAProperty  -Name -Type AllOf -ObjectDefinitions 'Pet', ( New-PodeOAStringProperty  -Name 'bark' -Object) |
  Add-PodeOAComponentSchema -Name 'Dog'

  Merge-PodeOAProperty  -Name -Type AllOf -ObjectDefinitions 'Pet', ( New-PodeOABoolProperty  -Name 'lovesRocks' -Object) |
  Add-PodeOAComponentSchema -Name 'Lizard'

```
```yaml
components:
  schemas:
    Pet:
      type: object
      required:
      - petType
      properties:
        petType:
          type: string
      discriminator:
        propertyName: petType
        mapping:
          dog: Dog
    Cat:
      allOf:
      - $ref: '#/components/schemas/Pet'
      - type: object
        # all other properties specific to a `Cat`
        properties:
          name:
            type: string
    Dog:
      allOf:
      - $ref: '#/components/schemas/Pet'
      - type: object
        # all other properties specific to a `Dog`
        properties:
          bark:
            type: string
    Lizard:
      allOf:
      - $ref: '#/components/schemas/Pet'
      - type: object
        # all other properties specific to a `Lizard`
        properties:
          lovesRocks:
            type: boolean
```

a payload like this:

```json
{
  "petType": "Cat",
  "name": "misty"
}
```

will indicate that the `Cat` schema be used.  Likewise this schema:

```json
{
  "petType": "dog",
  "bark": "soft"
}
```

will map to `Dog` because of the definition in the `mappings` element.


#### <a name="xmlObject"></a>XML Object

A metadata object that allows for more fine-tuned XML model definitions.

When using arrays, XML element names are *not* inferred (for singular/plural forms) and the `name` property SHOULD be used to add that information.
See examples for expected behavior.

##### Fixed Fields
| Field Name                           |   Type    | `New-PodeOA(*)Property` | Description                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------ | :-------: | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="xmlName"></a>name           | `string`  | `-XmlName`              | Replaces the name of the element/attribute used for the described schema property. When defined within `items`, it will affect the name of the individual XML elements within the list. When defined alongside `type` being `array` (outside the `items`), it will affect the wrapping element and only if `wrapped` is `true`. If `wrapped` is `false`, it will be ignored. |
| <a name="xmlNamespace"></a>namespace | `string`  | `-XmlNameSpace`         | The URI of the namespace definition. Value MUST be in the form of an absolute URI.                                                                                                                                                                                                                                                                                           |
| <a name="xmlPrefix"></a>prefix       | `string`  | `-XmlPrefix`            | The prefix to be used for the [name](#xmlName).                                                                                                                                                                                                                                                                                                                              |
| <a name="xmlAttribute"></a>attribute | `boolean` | `-XmlAttribute`         | Declares whether the property definition translates to an attribute instead of an element. Default value is `false`.                                                                                                                                                                                                                                                         |
| <a name="xmlWrapped"></a>wrapped     | `boolean` | `-XmlWrapped`           | MAY be used only for an array definition. Signifies whether the array is wrapped (for example, `<books><book/><book/></books>`) or unwrapped (`<book/><book/>`). Default value is `false`. The definition takes effect only when defined alongside `type` being `array` (outside the `items`).                                                                               |

(*) `New-PodeOAIntProperty` \| `New-PodeOAStringProperty`  \| `New-PodeOABoolProperty` \| `New-PodeOANumberProperty` \| `New-PodeOAObjectProperty`  \|`New-PodeOASchemaProperty`

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### XML Object Examples

The examples of the XML object definitions are included inside a property definition of a [Schema Object](#schemaObject) with a sample of the XML representation of it.

###### No XML Element

Basic string property:
```powershell
New-PodeOAStringProperty  -Name 'animals'
```
```json
{
    "animals": {
        "type": "string"
    }
}
```

```yaml
animals:
  type: string
```

```xml
<animals>...</animals>
```

Basic string array property ([`wrapped`](#xmlWrapped) is `false` by default):
```powershell
New-PodeOAStringProperty  -Name 'animals' -Array
```
```json
{
    "animals": {
        "type": "array",
        "items": {
            "type": "string"
        }
    }
}
```

```yaml
animals:
  type: array
  items:
    type: string
```

```xml
<animals>...</animals>
<animals>...</animals>
<animals>...</animals>
```

###### XML Name Replacement
```powershell
New-PodeOAStringProperty  -Name 'animals'  -XmlName 'animal'
```
```json
{
  "animals": {
    "type": "string",
    "xml": {
      "name": "animal"
    }
  }
}
```

```yaml
animals:
  type: string
  xml:
    name: animal
```

```xml
<animal>...</animal>
```


###### XML Attribute, Prefix and Namespace

In this example, a full model definition is shown.
```powershell
New-PodeOAIntProperty -Name 'id' -Format Int32 -XmlAttribute | New-PodeOAStringProperty -Name 'name' -XmlPrefix 'sample' -XmlNamespace 'http://example.com/schema/sample' |
  New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name 'Person'
```
```json
{
  "Person": {
    "type": "object",
    "properties": {
      "id": {
        "type": "integer",
        "format": "int32",
        "xml": {
          "attribute": true
        }
      },
      "name": {
        "type": "string",
        "xml": {
          "namespace": "http://example.com/schema/sample",
          "prefix": "sample"
        }
      }
    }
  }
}
```

```yaml
Person:
  type: object
  properties:
    id:
      type: integer
      format: int32
      xml:
        attribute: true
    name:
      type: string
      xml:
        namespace: http://example.com/schema/sample
        prefix: sample
```

```xml
<Person id="123">
    <sample:name xmlns:sample="http://example.com/schema/sample">example</sample:name>
</Person>
```

###### XML Arrays

Changing the element names:
```powershell
New-PodeOAStringProperty   -Array -XmlItemName 'animal' | Add-PodeOAComponentSchema -Name 'animals'
```
```json
{
  "animals": {
    "type": "array",
    "items": {
      "type": "string",
      "xml": {
        "name": "animal"
      }
    }
  }
}
```

```yaml
animals:
  type: array
  items:
    type: string
    xml:
      name: animal
```

```xml
<animal>value</animal>
<animal>value</animal>
```

The external `name` property has no effect on the XML:
```powershell
New-PodeOAStringProperty -Array -XmlItemName 'animal' -XmlName 'aliens' | Add-PodeOAComponentSchema -Name 'animals'
```
```json
{
  "animals": {
    "type": "array",
    "items": {
      "type": "string",
      "xml": {
        "name": "animal"
      }
    },
    "xml": {
      "name": "aliens"
    }
  }
}
```

```yaml
animals:
  type: array
  items:
    type: string
    xml:
      name: animal
  xml:
    name: aliens
```

```xml
<animal>value</animal>
<animal>value</animal>
```

Even when the array is wrapped, if a name is not explicitly defined, the same name will be used both internally and externally:
```powershell
New-PodeOAStringProperty -Array -XmlWrapped  | Add-PodeOAComponentSchema -Name 'animals'
```
```json
{
  "animals": {
    "type": "array",
    "items": {
      "type": "string"
    },
    "xml": {
      "wrapped": true
    }
  }
}
```

```yaml
animals:
  type: array
  items:
    type: string
  xml:
    wrapped: true
```

```xml
<animals>
  <animals>value</animals>
  <animals>value</animals>
</animals>
```

To overcome the naming problem in the example above, the following definition can be used:
```powershell
New-PodeOAStringProperty -Array -XmlWrapped -XmlItemName 'animal' | Add-PodeOAComponentSchema -Name 'animals'
```
```json
{
  "animals": {
    "type": "array",
    "items": {
      "type": "string",
      "xml": {
        "name": "animal"
      }
    },
    "xml": {
      "wrapped": true
    }
  }
}
```

```yaml
animals:
  type: array
  items:
    type: string
    xml:
      name: animal
  xml:
    wrapped: true
```

```xml
<animals>
  <animal>value</animal>
  <animal>value</animal>
</animals>
```

Affecting both internal and external names:
```powershell
New-PodeOAStringProperty -Array -XmlWrapped -XmlItemName 'animal' -XmlName 'aliens' | Add-PodeOAComponentSchema -Name 'animals'
```
```json
{
  "animals": {
    "type": "array",
    "items": {
      "type": "string",
      "xml": {
        "name": "animal"
      }
    },
    "xml": {
      "name": "aliens",
      "wrapped": true
    }
  }
}
```

```yaml
animals:
  type: array
  items:
    type: string
    xml:
      name: animal
  xml:
    name: aliens
    wrapped: true
```

```xml
<aliens>
  <animal>value</animal>
  <animal>value</animal>
</aliens>
```

If we change the external element but not the internal ones:

```json
{
  "animals": {
    "type": "array",
    "items": {
      "type": "string"
    },
    "xml": {
      "name": "aliens",
      "wrapped": true
    }
  }
}
```

```yaml
animals:
  type: array
  items:
    type: string
  xml:
    name: aliens
    wrapped: true
```

```xml
<aliens>
  <aliens>value</aliens>
  <aliens>value</aliens>
</aliens>
```

#### <a name="securitySchemeObject"></a>Security Scheme Object

Defines a security scheme that can be used by the operations.
Supported schemes are HTTP authentication, an API key (either as a header, a cookie parameter or as a query parameter), OAuth2's common flows (implicit, password, client credentials and authorization code) as defined in [RFC6749](https://tools.ietf.org/html/rfc6749), and [OpenID Connect Discovery](https://tools.ietf.org/html/draft-ietf-oauth-discovery-06).

##### Fixed Fields
| Field Name                                                    |                  Type                   | Applies To          | Description                                                                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------- | :-------------------------------------: | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="securitySchemeType"></a>type                         |                `string`                 | Any                 | **REQUIRED**. The type of the security scheme. Valid values are `"apiKey"`, `"http"`, `"oauth2"`, `"openIdConnect"`.                                                                                                                                                                                                                   |
| <a name="securitySchemeDescription"></a>description           |                `string`                 | Any                 | A short description for security scheme. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.                                                                                                                                                                                                   |
| <a name="securitySchemeName"></a>name                         |                `string`                 | `apiKey`            | **REQUIRED**. The name of the header, query or cookie parameter to be used.                                                                                                                                                                                                                                                            |
| <a name="securitySchemeIn"></a>in                             |                `string`                 | `apiKey`            | **REQUIRED**. The location of the API key. Valid values are `"query"`, `"header"` or `"cookie"`.                                                                                                                                                                                                                                       |
| <a name="securitySchemeScheme"></a>scheme                     |                `string`                 | `http`              | **REQUIRED**. The name of the HTTP Authorization scheme to be used in the [Authorization header as defined in RFC7235](https://tools.ietf.org/html/rfc7235#section-5.1).  The values used SHOULD be registered in the [IANA Authentication Scheme registry](https://www.iana.org/assignments/http-authschemes/http-authschemes.xhtml). |
| <a name="securitySchemeBearerFormat"></a>bearerFormat         |                `string`                 | `http` (`"bearer"`) | A hint to the client to identify how the bearer token is formatted.  Bearer tokens are usually generated by an authorization server, so this information is primarily for documentation purposes.                                                                                                                                      |
| <a name="securitySchemeFlows"></a>flows                       | [OAuth Flows Object](#oauthFlowsObject) | `oauth2`            | **REQUIRED**. An object containing configuration information for the flow types supported.                                                                                                                                                                                                                                             |
| <a name="securitySchemeOpenIdConnectUrl"></a>openIdConnectUrl |                `string`                 | `openIdConnect`     | **REQUIRED**. OpenId Connect URL to discover OAuth2 configuration values. This MUST be in the form of a URL.                                                                                                                                                                                                                           |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### Security Scheme Object Example

###### Basic Authentication Sample
```powershell
New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'basic' -ScriptBlock {
        param($username, $password)
        # check if the user is valid
        return @{ User = $user }
}
```
```json
{
  "type": "http",
  "scheme": "basic"
}
```

```yaml
type: http
scheme: basic
```

###### API Key Sample
```powershell
 New-PodeAuthScheme -ApiKey -Location 'Header' | Add-PodeAuth -Name 'ApiKey' -ScriptBlock {
        param($key)
        # check if the key is valid, and get user
        return @{ User = $user }
    }
```
```json
{
  "type": "apiKey",
  "name": "api_key",
  "in": "header"
}
```

```yaml
type: apiKey
name: api_key
in: header
```

###### JWT Bearer Sample
```powershell
New-PodeAuthScheme -Bearer -AsJWT | Add-PodeAuth -Name 'Example' -Sessionless -ScriptBlock {
    param($payload)
    # check if the key is valid, and get user
    return @{ User = $user }
}
```
```json
{
  "type": "http",
  "scheme": "bearer",
  "bearerFormat": "JWT",
}
```

```yaml
type: http
scheme: bearer
bearerFormat: JWT
```

###### Implicit OAuth2 Sample
```powershell

New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'read:pets' -Description 'read your pets'
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'write:pets' -Description 'modify pets in your account'

New-PodeAuthScheme -OAuth2 -ClientId $ClientId -ClientSecret $ClientSecret -AuthoriseUrl "http://example.org/api/oauth/dialog" `
  -TokenUrl 'http://example.org/api/oauth/token' -Scope 'read:pets', 'write:pets'  |
    Add-PodeAuth -Name 'petstore_auth' -FailureUrl 'http://example.org/api/oauth/dialog' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)
        return @{ User = $user }
    }
```json
{
  "type": "oauth2",
  "flows": {
    "implicit": {
      "authorizationUrl": "https://example.com/api/oauth/dialog",
      "tokenUrl": "http://example.org/api/oauth/token"
      "scopes": {
        "write:pets": "modify pets in your account",
        "read:pets": "read your pets"
      }
    }
  }
}
```

```yaml
type: oauth2
flows:
  implicit:
    authorizationUrl: https://example.com/api/oauth/dialog
    tokenUrl: http://example.org/api/oauth/token
    scopes:
      write:pets: modify pets in your account
      read:pets: read your pets
```

#### <a name="oauthFlowsObject"></a>OAuth Flows Object

Allows configuration of the supported OAuth Flows.

##### Fixed Fields
| Field Name                                                  |                 Type                  | Description                                                                                           |
| ----------------------------------------------------------- | :-----------------------------------: | ----------------------------------------------------------------------------------------------------- |
| <a name="oauthFlowsImplicit"></a>implicit                   | [OAuth Flow Object](#oauthFlowObject) | Configuration for the OAuth Implicit flow                                                             |
| <a name="oauthFlowsPassword"></a>password                   | [OAuth Flow Object](#oauthFlowObject) | Configuration for the OAuth Resource Owner Password flow                                              |
| <a name="oauthFlowsClientCredentials"></a>clientCredentials | [OAuth Flow Object](#oauthFlowObject) | Configuration for the OAuth Client Credentials flow.  Previously called `application` in OpenAPI 2.0. |
| <a name="oauthFlowsAuthorizationCode"></a>authorizationCode | [OAuth Flow Object](#oauthFlowObject) | Configuration for the OAuth Authorization Code flow.  Previously called `accessCode` in OpenAPI 2.0.  |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

#### <a name="oauthFlowObject"></a>OAuth Flow Object

Configuration details for a supported OAuth Flow

##### Fixed Fields
| Field Name                                               |          Type           | Applies To                                                            | Description                                                                                                                                           |
| -------------------------------------------------------- | :---------------------: | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="oauthFlowAuthorizationUrl"></a>authorizationUrl |        `string`         | `oauth2` (`"implicit"`, `"authorizationCode"`)                        | **REQUIRED**. The authorization URL to be used for this flow. This MUST be in the form of a URL.                                                      |
| <a name="oauthFlowTokenUrl"></a>tokenUrl                 |        `string`         | `oauth2` (`"password"`, `"clientCredentials"`, `"authorizationCode"`) | **REQUIRED**. The token URL to be used for this flow. This MUST be in the form of a URL.                                                              |
| <a name="oauthFlowRefreshUrl"></a>refreshUrl             |        `string`         | `oauth2`                                                              | The URL to be used for obtaining refresh tokens. This MUST be in the form of a URL.                                                                   |
| <a name="oauthFlowScopes"></a>scopes                     | Map[`string`, `string`] | `oauth2`                                                              | **REQUIRED**. The available scopes for the OAuth2 security scheme. A map between the scope name and a short description for it. The map MAY be empty. |

This object MAY be extended with [Specification Extensions](#specificationExtensions).

##### OAuth Flow Object Examples

```JSON
{
  "type": "oauth2",
  "flows": {
    "implicit": {
      "authorizationUrl": "https://example.com/api/oauth/dialog",
      "scopes": {
        "write:pets": "modify pets in your account",
        "read:pets": "read your pets"
      }
    },
    "authorizationCode": {
      "authorizationUrl": "https://example.com/api/oauth/dialog",
      "tokenUrl": "https://example.com/api/oauth/token",
      "scopes": {
        "write:pets": "modify pets in your account",
        "read:pets": "read your pets"
      }
    }
  }
}
```

```yaml
type: oauth2
flows:
  implicit:
    authorizationUrl: https://example.com/api/oauth/dialog
    scopes:
      write:pets: modify pets in your account
      read:pets: read your pets
  authorizationCode:
    authorizationUrl: https://example.com/api/oauth/dialog
    tokenUrl: https://example.com/api/oauth/token
    scopes:
      write:pets: modify pets in your account
      read:pets: read your pets
```

#### <a name="securityRequirementObject"></a>Security Requirement Object

Lists the required security schemes to execute this operation.
The name used for each property MUST correspond to a security scheme declared in the [Security Schemes](#componentsSecuritySchemes) under the [Components Object](#componentsObject).

Security Requirement Objects that contain multiple schemes require that all schemes MUST be satisfied for a request to be authorized.
This enables support for scenarios where multiple query parameters or HTTP headers are required to convey security information.

When a list of Security Requirement Objects is defined on the [OpenAPI Object](#oasObject) or [Operation Object](#operationObject), only one of the Security Requirement Objects in the list needs to be satisfied to authorize the request.

##### Patterned Fields

| Field Pattern                                 |    Type    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| --------------------------------------------- | :--------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="securityRequirementsName"></a>{name} | [`string`] | Each name MUST correspond to a security scheme which is declared in the [Security Schemes](#componentsSecuritySchemes) under the [Components Object](#componentsObject). If the security scheme is of type `"oauth2"` or `"openIdConnect"`, then the value is a list of scope names required for the execution, and the list MAY be empty if authorization does not require a specified scope. For other security scheme types, the array MUST be empty. |

##### Security Requirement Object Examples

###### Non-OAuth2 Security Requirement
```powershell
New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'api_key' -Sessionless -ScriptBlock {
        param($username, $password)
        # check if the user is valid
        return @{ User = $user }
    }
Add-PodeRoute -PassThru -Method Get -Path '/pet/#id' -Authentication 'api_key' -ScriptBlock {
    #code here
  }
```
```json
{
  "/pet2/{petId}": {
    "get": {
        "petId": {
          "schema": {
              "type": "integer",
              "format": "int64"
          },
          "description": "ID of the pet",
          "required": true,
          "in": "path"
        }
    },
    "security": [
      {
        "api_key": []
      }
    ]
  }
}
```

```yaml
/pet2/{petId} :
  get :
    petId :
      schema :
        type : integer
        format : int64
      description : ID of the pet
      required : true
      in : path
  security:
    - api_key: []
```

###### OAuth2 Security Requirement
```powershell
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'read:pets' -Description 'read your pets'
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'write:pets' -Description 'modify pets in your account'

New-PodeAuthScheme -OAuth2 -ClientId $ClientId -ClientSecret $ClientSecret -AuthoriseUrl "http://example.org/api/oauth/dialog" `
  -TokenUrl 'http://example.org/api/oauth/token' -Scope 'read:pets', 'write:pets'  |
    Add-PodeAuth -Name 'petstore_auth' -FailureUrl 'http://example.org/api/oauth/dialog' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)
        #Auth here
        return @{ User = $user }
    }

Add-PodeRoute -PassThru -Method post -Path '/pet/#id' -Authentication 'petstore_auth' -Scope "write:pets",
  "read:pets" -ScriptBlock {
    #code here
  }
```
```json
{
  "/pet2/{petId}": {
    "post": {
        "petId": {
          "schema": {
              "type": "integer",
              "format": "int64"
          },
          "description": "ID of the pet",
          "required": true,
          "in": "path"
        }
    },
    "security": [
      {
        "petstore_auth": [
            "write:pets",
            "read:pets"
        ]
      }
    ]
  }
}
```

```yaml
/pet2/{petId} :
  post :
    petId :
      schema :
        type : integer
        format : int64
      description : ID of the pet
      required : true
      in : path
  security:
    - petstore_auth:
      - write:pets
      - read:pets
```

###### Optional OAuth2 Security

Optional OAuth2 security as would be defined in an <a href="#openapi-object">OpenAPI Object</a> or an <a href="#operation-object">Operation Object</a>:
```powershell
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'read:pets' -Description 'read your pets'
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'write:pets' -Description 'modify pets in your account'

New-PodeAuthScheme -OAuth2 -ClientId $ClientId -ClientSecret $ClientSecret -AuthoriseUrl "http://example.org/api/oauth/dialog" `
  -TokenUrl 'http://example.org/api/oauth/token' -Scope 'read:pets', 'write:pets'  |
    Add-PodeAuth -Name 'petstore_auth' -FailureUrl 'http://example.org/api/oauth/dialog' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)
        #Auth here
        return @{ User = $user }
    }

 Add-PodeRoute -PassThru -Method put -Path '/pet/#id' -Authentication 'petstore_auth' -Scope "write:pets",
    "read:pets"  -AllowAnon -ScriptBlock {
      #code here
    }
```
```json
{
  "/pet2/{petId}": {
    "post": {
        "petId": {
          "schema": {
              "type": "integer",
              "format": "int64"
          },
          "description": "ID of the pet",
          "required": true,
          "in": "path"
        }
    },
    "security": [
      {},
      {
        "petstore_auth": [
            "write:pets",
            "read:pets"
        ]
      }
    ]
  }
}
```

```yaml
/pet2/{petId} :
  put :
    petId :
      schema :
        type : integer
        format : int64
      description : ID of the pet
      required : true
      in : path
  security:
    - petstore_auth:
      - write:pets
      - read:pets
    - {}
```

### <a name="specificationExtensions"></a>Specification Extensions

While the OpenAPI Specification tries to accommodate most use cases, additional data can be added to extend the specification at certain points.

The extensions properties are implemented as patterned fields that are always prefixed by `"x-"`.

| Field Pattern                    | Type  | Description                                                                                                                                                                                                    |
| -------------------------------- | :---: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="infoExtensions"></a>^x- |  Any  | Allows extensions to the OpenAPI Schema. The field name MUST begin with `x-`, for example, `x-internal-id`. The value can be `null`, a primitive, an array or an object. Can have any valid JSON format value. |

The extensions may or may not be supported by the available tooling, but those may be extended as well to add requested support (if tools are internal or open-sourced).

### <a name="securityFiltering"></a>Security Filtering

Some objects in the OpenAPI Specification MAY be declared and remain empty, or be completely removed, even though they are inherently the core of the API documentation.

The reasoning is to allow an additional layer of access control over the documentation.
While not part of the specification itself, certain libraries MAY choose to allow access to parts of the documentation based on some form of authentication/authorization.

Two examples of this:

1. The [Paths Object](#pathsObject) MAY be empty. It may be counterintuitive, but this may tell the viewer that they got to the right place, but can't access any documentation. They'd still have access to the [Info Object](#infoObject) which may contain additional information regarding authentication.
2. The [Path Item Object](#pathItemObject) MAY be empty. In this case, the viewer will be aware that the path exists, but will not be able to see any of its operations or parameters. This is different from hiding the path itself from the [Paths Object](#pathsObject), because the user will be aware of its existence. This allows the documentation provider to finely control what the viewer can see.

## <a name="revisionHistory"></a>Appendix A: Revision History

| Version    | Date       | Notes                                             |
| ---------- | ---------- | ------------------------------------------------- |
| 3.0.3-Pode | 2023-11-20 | OpenAPI Specification 3.0.3 Pode Version          |
| 3.0.3      | 2020-02-20 | Patch release of the OpenAPI Specification 3.0.3  |
| 3.0.2      | 2018-10-08 | Patch release of the OpenAPI Specification 3.0.2  |
| 3.0.1      | 2017-12-06 | Patch release of the OpenAPI Specification 3.0.1  |
| 3.0.0      | 2017-07-26 | Release of the OpenAPI Specification 3.0.0        |
| 3.0.0-rc2  | 2017-06-16 | rc2 of the 3.0 specification                      |
| 3.0.0-rc1  | 2017-04-27 | rc1 of the 3.0 specification                      |
| 3.0.0-rc0  | 2017-02-28 | Implementer's Draft of the 3.0 specification      |
| 2.0        | 2015-12-31 | Donation of Swagger 2.0 to the OpenAPI Initiative |
| 2.0        | 2014-09-08 | Release of Swagger 2.0                            |
| 1.2        | 2014-03-14 | Initial release of the formal document.           |
| 1.1        | 2012-08-22 | Release of Swagger 1.1                            |
| 1.0        | 2011-08-10 | First release of the Swagger Specification        |