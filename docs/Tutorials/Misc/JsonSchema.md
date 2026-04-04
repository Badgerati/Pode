# JSON Schema

You can construct hashtable representations of JSON Schema objects in Pode, which follows the specification [outlined here](https://json-schema.org/specification).

The hashtable objects can then be converted to JSON later, using `ConvertTo-Json` - or [`Write-PodeJsonResponse`](../../../Functions/Responses/Write-PodeJsonResponse).

## Types

The following types are supported:

* Null
* Boolean
* Integer
* Number
* String
* Array
* Object

### Null

To construct a simple `null` object type definition use [`New-PodeJsonSchemaNull`](../../../Functions/JsonSchema/New-PodeJsonSchemaNull):

```powershell
$def = New-PodeJsonSchemaNull

# return:

@{
    type = 'null'
}
```

### Boolean

To construct a simple `boolean` object type definition use [`New-PodeJsonSchemaBoolean`](../../../Functions/JsonSchema/New-PodeJsonSchemaBoolean):

```powershell
$def = New-PodeJsonSchemaBoolean

# returns:
@{
    type = 'boolean'
}
```

**An boolean with constant value:**

```powershell
$def = New-PodeJsonSchemaBoolean -Constant $true

# returns:
@{
    type  = 'boolean'
    const = $true
}
```

### Integer

To construct a simple `integer` object type definition use [`New-PodeJsonSchemaInteger`](../../../Functions/JsonSchema/New-PodeJsonSchemaInteger):

```powershell
$def = New-PodeJsonSchemaInteger

# returns:
@{
    type = 'integer'
}
```

**An integer with constant value:**

```powershell
$def = New-PodeJsonSchemaInteger -Constant 42

# returns:
@{
    type = 'integer'
    const = 42
}
```

**An integer with minimum and maximum:**

```powershell
$def = New-PodeJsonSchemaInteger -Minimum 0 -Maximum 100

# returns:
@{
    type    = 'integer'
    minimum = 0
    maximum = 100
}
```

**An integer with predefined values:**

```powershell
$def = New-PodeJsonSchemaInteger -Enum 1, 2, 4, 8, 16

# returns:
@{
    type = 'integer'
    enum = @(1, 2, 4, 8, 16)
}
```

### Number

To construct a simple `number` object type definition use [`New-PodeJsonSchemaNumber`](../../../Functions/JsonSchema/New-PodeJsonSchemaNumber):

```powershell
$def = New-PodeJsonSchemaNumber

# returns:
@{
    type = 'number'
}
```

**A number with constant value:**

```powershell
$def = New-PodeJsonSchemaNumber -Constant 42

# returns:
@{
    type = 'number'
    const = 42
}
```

**A number with minimum and maximum:**

```powershell
$def = New-PodeJsonSchemaNumber -Minimum 0 -Maximum 100

# returns:
@{
    type    = 'number'
    minimum = 0
    maximum = 100
}
```

**A number with predefined values:**

```powershell
$def = New-PodeJsonSchemaNumber -Enum 1, 2, 4, 8, 16

# returns:
@{
    type = 'number'
    enum = @(1, 2, 4, 8, 16)
}
```

### String

To construct a simple `string` object type definition use [`New-PodeJsonSchemaString`](../../../Functions/JsonSchema/New-PodeJsonSchemaString):

```powershell
$def = New-PodeJsonSchemaString

# returns:
@{
    type = 'string'
}
```

**A string with constant value:**

```powershell
$def = New-PodeJsonSchemaString -Constant 'Hello, there'

# returns:
@{
    type = 'string'
    const = 'Hello, there'
}
```

**A string with minimum and maximum length:**

```powershell
$def = New-PodeJsonSchemaString -MinLength 5 -MaxLength 20

# returns:
@{
    type      = 'string'
    minLength = 5
    maxLength = 20
}
```

**A string with predefined values:**

```powershell
$def = New-PodeJsonSchemaString -Enum 'Red', 'Blue', 'Green'

# returns:
@{
    type = 'string'
    enum = @('Red', 'Blue', 'Green')
}
```

### Array

An `array` takes one of the Null, Boolean, Integer, Number, or String definitions above to define its own items:

```powershell
# definition for an array of strings
$def = New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaString)

# returns:
@{
    type  = 'array'
    items = @{
        type = 'string'
    }
}
```

**An array with minimum and maximum items:**

```powershell
$def = New-PodeJsonSchemaArray -MinItems 1 -MaxItems 5 -Item (New-PodeJsonSchemaString)

# returns:
@{
    type     = 'array'
    minItems = 1
    maxItems = 5
    items    = @{
        type = 'string'
    }
}
```

**An array with unique items only:**
```powershell
$def = New-PodeJsonSchemaArray -Unique -MaxItems 2 -Item (
    New-PodeJsonSchemaString -Enum 'Red', 'Green', 'Blue', 'Yellow'
)

# returns:
@{
    type        = 'array'
    maxItems    = 2
    uniqueItems = $true
    items       = @{
        type = 'string'
        enum = @('Red', 'Green', 'Blue', 'Yellow')
    }
}
```

### Object

An `object` uses the definitions above for Null, Boolean, Integer, Number, String and/or Array (or Object again) to define its own properties. However, instead of using the definitions directly, you need to first create a property definition using [`New-PodeJsonSchemaProperty`](../../../Functions/JsonSchema/New-PodeJsonSchemaProperty) - this allows you to explicitly name a definition, and specify if it's required.

A basic `object`, which can accept any properties, looks as follows:

```powershell
$def = New-PodeJsonSchemaObject

# returns:
@{
    type = 'object'
}
```

An `object` with two properties to define a person, `name` of which is required:

```powershell
$def = New-PodeJsonSchemaObject -Property @(
    (New-PodeJsonSchemaProperty -Name 'name' -Definition (New-PodeJsonSchemaString) -Required),
    (New-PodeJsonSchemaProperty -Name 'age' -Definition (New-PodeJsonSchemaInteger -Minimum 0))
)

# returns:
@{
    type       = 'object'
    required   = @('name')
    properties = @{
        name = @{
            type = 'string'
        }
        age = @{
            type    = 'integer'
            minimum = 0
        }
    }
}
```

## Merging

You can merge multiple JSON Schema type definitions together, using either `allOf`, `anyOf`, `oneOf`, or `not` to create more complex type definitions.

### All Of

A merged type definition using `allOf` specifies that the value must match all of the defined schema of the type definitions supplied.

For example, the following describes a type that has to be a `string` with minimum length of 5, and a maximum length of 10:

```powershell
$def = Merge-PodeJsonSchema -Type 'AllOf' -Definition @(
    (New-PodeJsonSchemaString -MinLength 5),
    (New-PodeJsonSchemaString -MaxLength 10)
)

# returns:
@{
    allOf = @(
        @{
            type      = 'string'
            minLength = 5
        }
        @{
            type      = 'string'
            maxLength = 10
        }
    )
}
```

### Any Of

A merged type definition using `anyOf` specifies that the value must match any of the defined schema of the type definitions supplied.

For example, the following describes a type that has to be either a `string` with maximum length of 5, or an `integer` with minimum value of 0:

```powershell
$def = Merge-PodeJsonSchema -Type 'AnyOf' -Definition @(
    (New-PodeJsonSchemaString -MaxLength 5),
    (New-PodeJsonSchemaInteger -Minimum 0)
)

# returns:
@{
    anyOf = @(
        @{
            type      = 'string'
            maxLength = 5
        }
        @{
            type    = 'integer'
            minimum = 0
        }
    )
}
```

### One Of

A merged type definition using `oneOf` specifies that the value must match exactly one of the defined schema of the type definitions supplied.

For example, the following describes a type that has to be either an `integer` that's a multiple of 5 or a multiple of 3 - but it cannot be both:

```powershell
$def = Merge-PodeJsonSchema -Type 'OneOf' -Definition @(
    (New-PodeJsonSchemaInteger -MultipleOf 5),
    (New-PodeJsonSchemaInteger -MultipleOf 3)
)

# returns:
@{
    oneOf = @(
        @{
            type       = 'integer'
            multipleOf = 5
        }
        @{
            type       = 'integer'
            multipleOf = 3
        }
    )
}
```

### Not

A merged type definition using `not` specifies that the value must not match the defined schema of the type definitions supplied.

For example, the following describes a type that cannot be a `string`:

```powershell
$def = Merge-PodeJsonSchema -Type 'Not' -Definition @(
    (New-PodeJsonSchemaString)
)

# returns:
@{
    not = @(
        @{
            type = 'string'
        }
    )
}
```
