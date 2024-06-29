
# Properties

Properties are used to create all Parameters and Schemas in OpenAPI. You can use the simple types on their own, or you can combine multiple of them together to form complex objects.

### Simple Types

There are 5 simple property types: Integers, Numbers, Strings, Booleans, and Schemas. Each of which can be created using the following functions:

* [`New-PodeOAIntProperty`](../../../Functions/OAProperties/New-PodeOAIntProperty)
* [`New-PodeOANumberProperty`](../../../Functions/OAProperties/New-PodeOANumberProperty)
* [`New-PodeOAStringProperty`](../../../Functions/OAProperties/New-PodeOAStringProperty)
* [`New-PodeOABoolProperty`](../../../Functions/OAProperties/New-PodeOABoolProperty)
* [`New-PodeOASchemaProperty`](../../../Functions//New-PodeOASchemaProperty)
* [`New-PodeOAMultiTypeProperty`](../../../Functions/OAProperties/New-PodeOAMultiTypeProperty) (Note: OpenAPI 3.1 only)

These properties can be created with a Name, and other flags such as Required and/or a Description:

```powershell
# simple integer
New-PodeOAIntProperty -Name 'userId'

# a float number with a max value of 100
New-PodeOANumberProperty -Name 'ratio' -Format Float -Maximum 100

# a string with a default value, and enum of options
New-PodeOAStringProperty -Name 'type' -Default 'admin' -Enum @('admin', 'user')

# a boolean that's required
New-PodeOABoolProperty -Name 'enabled' -Required

# a schema property that references another component schema
New-PodeOASchemaProperty -Name 'Config' -Reference 'ConfigSchema'

# a string or an integer or a null value (only available with OpenAPI 3.1)
New-PodeOAMultiTypeProperty -Name 'multi' -Type integer,string -Nullable
```

On their own, like above, the simple properties don't really do much. However, you can combine that together to make complex objects/arrays as defined below.

### Arrays

There isn't a dedicated function to create an array property, instead there is an `-Array` switch on each of the property functions - both Object and the above simple properties.

If you supply the `-Array` switch to any of the above simple properties, this will define an array of that type - the `-Name` parameter can also be omitted if only a simple array if required.

For example, the below will define an integer array:

```powershell
New-PodeOAIntProperty -Array
```

When used in a Response, this could return the following JSON example:

```json
[
    0,
    1,
    2
]
```

### Objects

An object property is a combination of multiple other properties - both simple, array of more objects.

There are two ways to define objects:

1. Similar to arrays, you can use the `-Object` switch on the simple properties.
2. You can use the [`New-PodeOAObjectProperty`](../../../Functions/OAProperties/New-PodeOAObjectProperty) function to combine multiple properties.

#### Simple

If you use the `-Object` switch on the simple property function, this will automatically wrap the property as an object. The Name for this is required.

For example, the below will define a simple `userId` integer object:

```powershell
New-PodeOAIntProperty -Name 'userId' -Object
```

In a response as JSON, this could look as follows:

```json
{
    "userId": 0
}
```

Furthermore, you can also supply both `-Array` and `-Object` switches:

```powershell
New-PodeOAIntProperty -Name 'userId' -Object -Array
```

This wil result in something like the following JSON:

```json
{
    "userId": [ 0, 1, 2 ]
}
```

#### Complex

Unlike the `-Object` switch that simply converts a single property into an object, the [`New-PodeOAObjectProperty`](../../../Functions/OAProperties/New-PodeOAObjectProperty) function can combine and convert multiple properties.

For example, the following will create an object using an Integer, String, and a Boolean:

Legacy Definition

```powershell
New-PodeOAObjectProperty -Properties (
    (New-PodeOAIntProperty -Name 'userId'),
    (New-PodeOAStringProperty -Name 'name'),
    (New-PodeOABoolProperty -Name 'enabled')
)
```

Using piping (new in Pode 2.10)

```powershell
New-PodeOAIntProperty -Name 'userId'| New-PodeOAStringProperty -Name 'name'|
   New-PodeOABoolProperty -Name 'enabled' |New-PodeOAObjectProperty
```

As JSON, this could look as follows:

```json
{
    "userId": 0,
    "name": "Gary Goodspeed",
    "enabled": true
}
```

You can also supply the `-Array` switch to the [`New-PodeOAObjectProperty`](../../../Functions/OAProperties/New-PodeOAObjectProperty) function. This will result in an array of objects. For example, if we took the above:

```powershell
New-PodeOAIntProperty -Name 'userId'| New-PodeOAStringProperty -Name 'name'|
   New-PodeOABoolProperty -Name 'enabled' |New-PodeOAObjectProperty -Array
```

As JSON, this could look as follows:

```json
[
    {
        "userId": 0,
        "name": "Gary Goodspeed",
        "enabled": true
    },
    {
        "userId": 1,
        "name": "Kevin",
        "enabled": false
    }
]
```

You can also combine objects into other objects:

```powershell
$usersArray = New-PodeOAIntProperty -Name 'userId'| New-PodeOAStringProperty -Name 'name'|
   New-PodeOABoolProperty -Name 'enabled' |New-PodeOAObjectProperty -Array

New-PodeOAObjectProperty -Properties @(
    (New-PodeOAIntProperty -Name 'found'),
    $usersArray
)
```

As JSON, this could look as follows:

```json
{
    "found": 2,
    "users": [
        {
            "userId": 0,
            "name": "Gary Goodspeed",
            "enabled": true
        },
        {
            "userId": 1,
            "name": "Kevin",
            "enabled": false
        }
    ]
}
```

### oneOf, anyOf and allOf Keywords

OpenAPI 3.x provides several keywords which you can use to combine schemas. You can use these keywords to create a complex schema or validate a value against multiple criteria.

* oneOf - validates the value against exactly one of the sub-schemas
* allOf - validates the value against all the sub-schemas
* anyOf - validates the value against any (one or more) of the sub-schemas

You can use the [`Merge-PodeOAProperty`](../../../Functions/OAProperties/Merge-PodeOAProperty) will instead define a relationship between the properties.

Unlike [`New-PodeOAObjectProperty`](../../../Functions/OAProperties/New-PodeOAObjectProperty) which combines and converts multiple properties into an Object, [`Merge-PodeOAProperty`](../../../Functions/OAProperties/Merge-PodeOAProperty) will instead define a relationship between the properties.

For example, the following will create an something like an C Union object using an Integer, String, and a Boolean:

```powershell
Merge-PodeOAProperty -Type OneOf -ObjectDefinitions @(
            (New-PodeOAIntProperty -Name 'userId' -Object),
            (New-PodeOAStringProperty -Name 'name' -Object),
            (New-PodeOABoolProperty -Name 'enabled' -Object)
        )
```

Or

```powershell
New-PodeOAIntProperty -Name 'userId' -Object |
        New-PodeOAStringProperty -Name 'name' -Object |
        New-PodeOABoolProperty -Name 'enabled' -Object |
        Merge-PodeOAProperty -Type OneOf
```

As JSON, this could look as follows:

```json
{
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "userId": {
          "type": "integer"
        }
      }
    },
    {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        }
      }
    },
    {
      "type": "object",
      "properties": {
        "enabled": {
          "type": "boolean",
          "default": false
        }
      }
    }
  ]
}
```

You can also supply a Component Schema created using [`Add-PodeOAComponentSchema`](../../../Functions/OAComponents/Add-PodeOAComponentSchema). For example, if we took the above:

```powershell
    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 -ReadOnly |
        New-PodeOAStringProperty -Name 'username' -Example 'theUser' -Required |
        New-PodeOAStringProperty -Name 'firstName' -Example 'John' |
        New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
        New-PodeOAStringProperty -Name 'email' -Format email -Example 'john@email.com' |
        New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
        New-PodeOAStringProperty -Name 'password' -Format Password -Example '12345' -Required |
        New-PodeOAStringProperty -Name 'phone' -Example '12345' |
        New-PodeOAIntProperty -Name 'userStatus'-Format int32 -Description 'User Status' -Example 1|
        New-PodeOAObjectProperty  -Name 'User' -XmlName 'user'  |
        Add-PodeOAComponentSchema

    New-PodeOAStringProperty -Name 'street' -Example '437 Lytton' -Required |
        New-PodeOAStringProperty -Name 'city' -Example 'Palo Alto' -Required |
        New-PodeOAStringProperty -Name 'state' -Example 'CA' -Required |
        New-PodeOAStringProperty -Name 'zip' -Example '94031' -Required |
        New-PodeOAObjectProperty -Name 'Address' -XmlName 'address' -Description 'Shipping Address' |
        Add-PodeOAComponentSchema

    Merge-PodeOAProperty -Type AllOf -ObjectDefinitions 'Address','User'

```

As JSON, this could look as follows:

```json
{
  "allOf": [
    {
      "$ref": "#/components/schemas/Address"
    },
    {
      "$ref": "#/components/schemas/User"
    }
  ]
}
```