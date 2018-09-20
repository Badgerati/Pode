# Include

## Description

The `include` function can only be used within a `.pode` view file; it allows you to include other views (html/pode/other) into a main view. This way you can have shared partial views (like headers, footers or navigation), and include them into your main views.

## Examples

### Example 1

The following example will include a header partial view file into below example `index.pode` file:

```html
<!-- /views/index.pode -->
<html>
    $(include shared/head)

    <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>

<!-- /views/shared/head.pode -->
<head>
    <title>Include Example</title>
</head>
```

### Example 2

The following example will include the header partial view file, but this time will supply some dynamic data:

```html
<!-- /views/index.pode -->
<html>
    $(include shared/head -d @{ 'PageName' = 'Index' })

    <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>

<!-- /views/shared/head.pode -->
<head>
    <title>Page: $($data.PageName)</title>
</head>
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to the view that should be included, relative to the `/views` directory | empty |
| Data | hashtable | false | A hashtable of dynamic data that will be supplied to `.pode`, and other third-party template engine, view files | `@{}` |
