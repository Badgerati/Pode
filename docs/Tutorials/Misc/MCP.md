# MCP

!!! note
    This is an initial implementation of MCP support, while initial testing has worked please expect aspects of the implementation to possibly change.

You can create MCP tools in PowerShell and host them via Pode over HTTP(S), for use by MCP servers such as GitHub Copilot.

There is support for the tools to have, or not have, parameters; you can also describe the tool/parameters for the MCP server using [JSON Schema](../JsonSchema).

## Groups

Tools are bundled into Groups, which lets you create a Tool and add it into one or more Groups - for example, you could have a `Default` Group where all Tools are added, or you could have a `ReadOnly` and `Admin` Groups to separate Tools.

To create a Group use [`Add-PodeMcpGroup`] with a Name and optional Description:

```powershell
Add-PodeMcpGroup -Name 'Default'
Add-PodeMcpGroup -Name 'ReadOnly'
Add-PodeMcpGroup -Name 'Admin' -Description 'Admin only Tools for management of services'
```

## Tools

An MCP Tool is simply just a ScriptBlock, with a Name and Description, and then added to the server using [`Add-PodeMcpTool`] - you also need to supply one or more Groups to assign the Tool into.

If the supplied ScriptBlock has no parameters, there's nothing more for you to do. However, if your ScriptBlock does have parameters then you'll need to define and describe them - you can use `-AutoSchema` for simple parameter, or the [JSON Schema](../JsonSchema) functions for advanced definitions.

### No Parameters

The following creates a new MCP Tool for returning all Windows Service names, regardless of state. This Tool has no parameters which need to be supplied, so a ScriptBlock, Name, Description, and Group is all that's required:

```powershell
Add-PodeMcpTool -Name 'GetWindowsServices' -Description 'Returns all Windows service names' -Group 'Default' -ScriptBlock {
        $services = Get-Service -ErrorAction Ignore | Select-Object Name
        return New-PodeMcpTextContent -Value $services
    }
```

Once added to your MCP server, you can ask `What services are on this machine?` and it will invoke the above Tool.

### AutoSchema

When creating a Tool which accepts parameters there is the option to have Pode automatically generate the JSON Schema, to do this you should supply `-AutoSchema` to [`Add-PodeMcpTool`].

!!! important
    Only simple types are supported: string, int, long, double, float, and bool (including arrays of these types).

To aid the generation, the following parameter Attributes are respected:

* `Parameter`
  * `Mandatory` for knowing if the parameter is required
  * `HelpMessage` is used as the parameter description
  * `DontShow` is used to not generate schema for the parameter
* `ValidateRange` is used the the min/max on integer/number types
* `ValidateSet` is used as the enum value for types
* `ValidateLength` is used for the min/max length on string types
* `ValidateCount` is used for min/max items on array types

Furthermore, the following PowerShell parameter types map the the following JSON Schema types:

| PowerShell | JSON      |
| ---------- | --------- |
| `[string]` | `string`  |
| `[int]`    | `integer` |
| `[long]`   | `integer` |
| `[double]` | `number`  |
| `[float]`  | `number`  |
| `[bool]`   | `boolean` |

For example, the following Tool will return the Windows Services on the current machine which are in a specified State:

```powershell
Add-PodeMcpTool -Name 'GetWindowsServicesByState' -Description 'Returns Windows service names for a given state' -Group 'Default' -AutoSchema -ScriptBlock {
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'The state of the services to retrieve')]
        [ValidateSet('Running', 'Stopped', 'Paused')]
        [string]
        $State
    )

    $services = Get-Service -ErrorAction Ignore | Where-Object { $_.Status -ieq $State } | Select-Object Name
    if (($null -eq $services) -or (Test-PodeIsEmpty $services)) {
        $services = "No services found in the '$State' state."
    }

    return New-PodeMcpTextContent -Value $services
}
```

Once added to your MCP server, you can ask `What services are running on this machine?` or `What services are stopped on this machine?` and it will invoke the above Tool.

### Custom Schema

Unlike the above automatically generated schema, there is also the option to manually define the schema yourself using [JSON Schema](../JsonSchema).

To do this you'll need to supply `-PassThru` to [`Add-PodeMcpTool`], and pipe the result into [`Add-PodeMcpToolProperty`] and describe the parameters - chaining the [`Add-PodeMcpToolProperty`] calls for each ScriptBlock parameter you need to define.

For example, building slightly on the above AutoSchema example, the following Tool will test if a specific Windows Service is present and in the specified State - but the schema is built manually. It is highly recommended to supply `-Description` to the JSON Schema functions, to help the MCP server further understand the parameters:

```powershell
Add-PodeMcpTool -Name 'TestWindowsServiceState' -Description 'Tests if a specified service is in a specified state' -Group 'Default' -ScriptBlock {
    param(
        [string]
        $Name,

        [ValidateSet('Running', 'Stopped', 'Paused')]
        [string]
        $State
    )

    $service = Get-Service -Name $Name -ErrorAction Ignore
    if ($null -eq $service) {
        return New-PodeMcpTextContent -Value "Service '$Name' not found."
    }

    if ($service.Status -ieq $State) {
        return New-PodeMcpTextContent -Value "Service '$Name' is in the '$State' state."
    }

    return New-PodeMcpTextContent -Value "Service '$Name' is not in the '$State' state. Current state: $($service.Status)"
} -PassThru |
    Add-PodeMcpToolProperty -Name 'Name' -Required -Definition (
        New-PodeJsonSchemaString -Description 'The name of the service to check'
    ) -PassThru |
    Add-PodeMcpToolProperty -Name 'State' -Required -Definition (
        New-PodeJsonSchemaString -Description 'The state to check for the service' -Enum 'Running', 'Stopped', 'Paused'
    )
```

Once added to your MCP server, you can ask `Is the WinRM service running on this machine?` and it will invoke the above Tool.

## Response Types

In the above Tool examples you'll have likely spotted the Tools return [`New-PodeMcpTextContent`]. This is because MCP tools should respond with one or more of the following types: text, image, and audio - each of which are represented by:

* [`New-PodeMcpTextContent`]
* [`New-PodeMcpImageContent`]
* [`New-PodeMcpAudioContent`]

These functions are mandatory to return from Tool ScriptBlocks, so Pode can appropriately format the responses.

## Routing

To actually host the created Tools, and let an MCP server list/invoke them, you need to configure Routing within Pode.

This can be done via the usual [`Add-PodeRoute`], and then within its ScriptBlock you call [`Resolve-PodeMcpRequest`] - supplying the Group of Tools the Route should be responsible for. Because we're using the standard [`Add-PodeRoute`] you can configure any path you require, as well a authentication, middleware, etc.

The [`Resolve-PodeMcpRequest`] call deals with parsing the MCP server request, and the handling of `initialize`, `tools/list`, and `tools/call` requests:

```powershell
Add-PodeRoute -Method Post -Path '/mcp' -ScriptBlock {
    Resolve-PodeMcpRequest -Group 'Default'
}
```

## MCP Server

To connect your MCP server of choice, you will need to configure it to look at the HTTP endpoint and Route path you've configured - if a "type" is needed it should be `http`.

### GitHub Copilot

For example, to configure GitHub Copilot in Visual Studio Code you would create a `.vscode/mcp.json` file with the following content (replace `url` with your configure endpoint/path):

```json
{
    "servers": {
        "services": {
            "type": "http",
            "url": "http://localhost:8080/mcp"
        }
    }
}
```

Once saved, you can open Copilot Chat and ask it questions to call your defined Tools.

## Full Example

The following is a simple but full example of a Pode server, which configures a simple MCP Tool which can be consumed by an MCP server. Once running, you'll need to configure your MCP server to look for tools at `http://localhost:8080/mcp`. Once connected, you'll be able to ask `What services are running on this machine?`.

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Create a simple default group for MCP tools
    Add-PodeMcpGroup -Name 'Default' -Description 'Default group for MCP tools'

    # Add a simple MCP tool for returning windows services names for a given state
    Add-PodeMcpTool -Name 'GetWindowsServicesByState' -Description 'Returns Windows service names for a given state' -Group 'Default' -AutoSchema -ScriptBlock {
        param(
            [Parameter(Mandatory = $true, HelpMessage = 'The state of the services to retrieve')]
            [ValidateSet('Running', 'Stopped', 'Paused')]
            [string]
            $State
        )

        $services = Get-Service -ErrorAction Ignore | Where-Object { $_.Status -ieq $State } | Select-Object Name
        if (($null -eq $services) -or (Test-PodeIsEmpty $services)) {
            $services = "No services found in the '$State' state."
        }

        return New-PodeMcpTextContent -Value $services
    }

    # Add the MCP route
    Add-PodeRoute -Method Post -Path '/mcp' -ScriptBlock {
        Resolve-PodeMcpRequest -Group 'Default'
    }
}
```
