<#
.SYNOPSIS
Resolves an MCP request from a client, invoking the appropriate logic based on the method and returning a response.

.DESCRIPTION
This function is responsible for handling incoming MCP requests, validating them, and invoking the appropriate logic
based on the requested method. It supports methods for initializing the MCP connection, listing available tools, calling
specific tools, and handling notifications.

Responses are returned in JSON-RPC 2.0 format.

.PARAMETER Group
The group to which the MCP tools belong. This allows for organizing tools into different groups.

.PARAMETER ServerName
The name of the MCP server. (Default: 'Pode MCP Server').

.PARAMETER ServerVersion
The version of the MCP server. (Default: Current Pode version).

.EXAMPLE
# resolve requests for MCP tools in a default group, using Pode server name and version
Add-PodeMcpGroup -Name 'default'
Resolve-PodeMcpRequest -Group 'default'

.EXAMPLE
# resolve requests for MCP tools in a custom group, with custom server name and version
Add-PodeMcpGroup -Name 'custom'
Resolve-PodeMcpRequest -Group 'custom' -ServerName 'Custom MCP Server' -ServerVersion '1.0.0'
#>
function Resolve-PodeMcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Group,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerName = 'Pode MCP Server',

        [Parameter()]
        [string]
        $ServerVersion
    )

    # validate the request
    if (!(Test-PodeMcpRequest -Group $Group)) {
        return
    }

    # invoke the appropriate logic per the MCP method
    $content = @{}

    switch ($WebEvent.Data['method'].ToLowerInvariant()) {
        'initialize' {
            # logic to initialize the MCP connection
            $content = Invoke-PodeMcpInitialize -ServerName $ServerName -ServerVersion $ServerVersion
            Write-PodeMcpSuccessResponse -Result $content
        }

        'tools/list' {
            # logic to list available tools
            $content = Invoke-PodeMcpToolList -Group $Group
            Write-PodeMcpSuccessResponse -Result $content
        }

        'tools/call' {
            # logic to call a specific tool
            $content = Invoke-PodeMcpToolCall -Group $Group
            if ($null -ne $content) {
                Write-PodeMcpSuccessResponse -Result $content
            }
        }

        { $_ -ilike 'notifications/*' } {
            # handle something here eventually, for now set send an HTTP 202
            Write-PodeMcpSuccessResponse
        }

        default {
            Write-PodeMcpErrorResponse -Message "Method '$($_)' not found" -Type MethodNotFound
        }
    }
}

<#
.SYNOPSIS
Builds a Textual response object for an MCP tool, which can be returned to the client.

.DESCRIPTION
This function creates a hashtable representing a textual response for an MCP tool. The hashtable includes a
'type' key with the value 'text', and a 'text' key containing the provided value. If the provided value is not a string,
it will be converted to a string using Out-String.

.PARAMETER Value
The value to be included in the textual response. This can be any object, which will be converted to a string if necessary.

.EXAMPLE
# create a simple text response for an MCP tool
New-PodeMcpTextContent -Value 'Hello, world!'

.EXAMPLE
# create a text response for an MCP tool from a non-string object
$data = @{ Name = 'Alice'; Age = 30 }
New-PodeMcpTextContent -Value $data
#>
function New-PodeMcpTextContent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [object]
        $Value
    )

    if ($null -eq $Value) {
        $Value = [string]::Empty
    }
    elseif ($Value -isnot [string]) {
        $Value = $Value | Out-String
    }

    return @{
        type = 'text'
        text = $Value
    }
}

<#
.SYNOPSIS
Builds an Image response object for an MCP tool, which can be returned to the client.

.DESCRIPTION
This function creates a hashtable representing an image response for an MCP tool. The hashtable includes a
'type' key with the value 'image', a 'data' key containing the base64-encoded image data, and a 'mimeType' key
specifying the MIME type of the image.

.PARAMETER Bytes
The byte array representing the image data.

.PARAMETER MimeType
The MIME type of the image.

.EXAMPLE
# create an image response for an MCP tool
$imageBytes = [System.IO.File]::ReadAllBytes('path\to\image.png')
New-PodeMcpImageContent -Bytes $imageBytes -MimeType 'image/png'
#>
function New-PodeMcpImageContent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [byte[]]
        $Bytes,

        [Parameter(Mandatory = $true)]
        [string]
        $MimeType
    )

    if ($null -eq $Bytes) {
        $Bytes = @()
    }

    return @{
        type     = 'image'
        data     = [Convert]::ToBase64String($Bytes)
        mimeType = $MimeType
    }
}

<#
.SYNOPSIS
Builds an Audio response object for an MCP tool, which can be returned to the client.

.DESCRIPTION
This function creates a hashtable representing an audio response for an MCP tool. The hashtable includes a
'type' key with the value 'audio', a 'data' key containing the base64-encoded audio data, and a 'mimeType' key
specifying the MIME type of the audio.

.PARAMETER Bytes
The byte array representing the audio data.

.PARAMETER MimeType
The MIME type of the audio.

.EXAMPLE
# create an audio response for an MCP tool
$audioBytes = [System.IO.File]::ReadAllBytes('path\to\audio.mp3')
New-PodeMcpAudioContent -Bytes $audioBytes -MimeType 'audio/mpeg'
#>
function New-PodeMcpAudioContent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [byte[]]
        $Bytes,

        [Parameter(Mandatory = $true)]
        [string]
        $MimeType
    )

    if ($null -eq $Bytes) {
        $Bytes = @()
    }

    return @{
        type     = 'audio'
        data     = [Convert]::ToBase64String($Bytes)
        mimeType = $MimeType
    }
}

<#
.SYNOPSIS
Adds a new MCP tool to the server.

.DESCRIPTION
Adds a new MCP tool to the server, optionally inside a custom Group.

.PARAMETER Name
The name of the MCP tool.

.PARAMETER Description
A brief description of the MCP tool, this is required to help MCP clients understand what the tool does.

.PARAMETER ScriptBlock
The ScriptBlock that defines the MCP tool's functionality.

.PARAMETER Group
The Group(s) to which the MCP tool belongs.

.PARAMETER AutoSchema
If set, the input schema for the tool will attempt to be automatically generated based on the parameters of the provided
ScriptBlock - using parameter attributes for additional context.

This only supports basic parameter types: string, int, long, double, float, and bool (including arrays of these types).

If supplied you don't need to manually define properties via Add-PodeMcpToolProperty, but you can still do so if you want
to and override the auto-generated schema for specific properties.

.PARAMETER PassThru
If set, the function will return the tool after it has been added to enable pipeline chaining.

.EXAMPLE
# add a simple MCP tool to a default group
Add-PodeMcpGroup -Name 'default'
Add-PodeMcpTool -Name 'Greet' -Description 'Returns a random greeting' -Group 'default' -ScriptBlock {
    $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
    $greeting = Get-Random -InputObject $greetings
    return New-PodeMcpTextContent -Value "$($greeting) from the Pode MCP tool!"
}

.EXAMPLE
# add a simple MCP tool to a custom group with auto-generated schema
Add-PodeMcpGroup -Name 'custom'
Add-PodeMcpTool -Name 'GreetPerson' -Description 'Returns a random greeting to a person' -Group 'custom' -AutoSchema -ScriptBlock {
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'The name of the person to greet')]
        [string]$Name
    )
    $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
    $greeting = Get-Random -InputObject $greetings
    return New-PodeMcpTextContent -Value "$($greeting), $($Name)! from the Pode MCP tool!"
}

.EXAMPLE
# add a simple MCP tool to a custom group, and return the tool for chaining
Add-PodeMcpGroup -Name 'custom'
Add-PodeMcpTool -Name 'GreetPersonInLocation' -Description 'Returns a random greeting to a person' -Group 'custom' -ScriptBlock {
    param(
        [string]$Name
    )
    $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
    $greeting = Get-Random -InputObject $greetings
    return New-PodeMcpTextContent -Value "$($greeting), $($Name)! via the Pode MCP tool!"
} -PassThru |
    Add-PodeMcpToolProperty -Name 'Name' -Required -Definition (
        New-PodeJsonSchemaString -Description 'The name of the person to greet'
    )
#>
function Add-PodeMcpTool {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Group,

        [switch]
        $AutoSchema,

        [switch]
        $PassThru
    )

    # make sure groups are unique
    $Group = $Group | Sort-Object -Unique

    # ensure the tool doesn't already exist, if so throw an error
    if (Test-PodeMcpTool -Name $Name) {
        throw ($PodeLocale.mcpToolAlreadyExistsExceptionMessage -f $Name)
    }

    # ensure the group(s) exist, if not throw an error
    foreach ($g in $Group) {
        if (Test-PodeMcpGroup -Name $g) {
            continue
        }

        throw ($PodeLocale.mcpToolGroupDoesNotExistExceptionMessage -f $g)
    }

    # initialize the tool info
    $toolInfo = @{
        Name        = $Name
        Description = $Description
        ScriptBlock = $ScriptBlock
        Groups      = @($Group)
        Properties  = @()
    }

    # if auto-schema allowed, attempt to generate basic input schema from the scriptblock parameters
    if ($AutoSchema) {
        Add-PodeMcpToolAutoSchema -Tool $toolInfo -ScriptBlock $ScriptBlock
    }

    # add the tool
    $PodeContext.Server.Mcp.Tools[$Name] = $toolInfo

    # add the tool to the specified group(s)
    foreach ($g in $Group) {
        $PodeContext.Server.Mcp.Groups[$g].Tools += $Name
    }

    # if required, return the tool info for chaining
    if ($PassThru) {
        return $toolInfo
    }
}

<#
.SYNOPSIS
Adds a property to an existing MCP tool, which will be included in the tool's input schema.

.DESCRIPTION
Adds a property to an existing MCP tool, which will be included in the tool's input schema. This allows you to define
the expected input for the tool, which can be used by MCP clients to understand how to call the tool and provide
better user experiences.

.PARAMETER Tool
The Tool to which the property should be added; this will be the output of Add-PodeMcpTool if -PassThru is used.

.PARAMETER Name
The Name of the property.

.PARAMETER Definition
The Definition of the property, which will be a JSON Schema built using the New-PodeJsonSchema* cmdlets.

.PARAMETER Required
Indicates whether the property is required.

.PARAMETER PassThru
If set, the function will return the tool after the property has been added to enable pipeline chaining.

.LINK
https://modelcontextprotocol.info/docs/concepts/tools/

.EXAMPLE
# add a property to an MCP tool using the output from Add-PodeMcpTool
Add-PodeMcpTool -Name 'GreetPersonInLocation' -Description 'Returns a random greeting to a person in a location' -ScriptBlock {
    param(
        [string]$Name,
        [string]$Location
    )
    $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
    $greeting = Get-Random -InputObject $greetings
    return New-PodeMcpTextContent -Value "$($greeting), $($Name) from $($Location)! via the Pode MCP tool!"
} -PassThru |
    Add-PodeMcpToolProperty -Name 'Name' -Required -Definition (
        New-PodeJsonSchemaString -Description 'The name of the person to greet'
    ) |
    Add-PodeMcpToolProperty -Name 'Location' -Required -Definition (
        New-PodeJsonSchemaString -Description 'The location of the person to greet'
    )
#>
function Add-PodeMcpToolProperty {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Tool,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Definition,

        [switch]
        $Required,

        [switch]
        $PassThru
    )

    # build the property definition
    $def = $Definition | New-PodeJsonSchemaProperty -Name $Name -Required:$Required

    # add the property to the tool's properties
    $Tool.Properties += $def

    # return tool if requested
    if ($PassThru) {
        return $Tool
    }
}

<#
.SYNOPSIS
Retrieves an MCP tool(s).

.DESCRIPTION
Retrieves an MCP tool or tools from the server based on the provided name and group.

.PARAMETER Name
The Name of the MCP tool to retrieve. If not specified, all tools in the specified group will be returned.

.PARAMETER Group
The Group(s) from which to retrieve the MCP tool(s).

.EXAMPLE
# retrieve a specific MCP tool by name from a default group
Get-PodeMcpTool -Name 'GreetPerson' -Group 'default'

.EXAMPLE
# retrieve all MCP tools from a specific group
Get-PodeMcpTool -Group 'custom'

.EXAMPLE
# attempt to retrieve a non-existent tool, which will return null
Get-PodeMcpTool -Name 'NonExistentTool'

.EXAMPLE
# attempt to retrieve tools from a non-existent group, which will return null
Get-PodeMcpTool -Group 'NonExistentGroup'
#>
function Get-PodeMcpTool {
    [CmdletBinding()]
    [OutputType([hashtable])]
    [OutputType([hashtable[]])]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter()]
        [string[]]
        $Group
    )

    $hasNames = ![string]::IsNullOrEmpty($Name)
    $hasGroups = ![string]::IsNullOrEmpty($Group)

    # if no group(s) or tool name(s) provided, return all tools
    if (!$hasGroups -and !$hasNames) {
        return $PodeContext.Server.Mcp.Tools.Values
    }

    # if group(s) provided, get tools in group(s)
    $groupTools = @()
    if ($hasGroups) {
        $groupTools = $Group | Foreach-Object {
            if ($PodeContext.Server.Mcp.Groups.ContainsKey($_)) {
                $PodeContext.Server.Mcp.Groups[$_].Tools
            }
        } | Sort-Object -Unique
    }

    # if no tool name(s) provided, use group tools - if group(s) provided we need to filter
    if (!$hasNames) {
        $Name = $groupTools
    }
    elseif ($hasGroups) {
        $Name = $Name | Where-Object { $groupTools -icontains $_ }
    }

    # now return tools if they exist
    return $Name | ForEach-Object {
        if ($PodeContext.Server.Mcp.Tools.ContainsKey($_)) {
            $PodeContext.Server.Mcp.Tools[$_]
        }
    }
}

<#
.SYNOPSIS
Tests the existence of an MCP tool.

.DESCRIPTION
Tests whether an MCP tool exists, or if it exists in the specified group.

.PARAMETER Name
The Name of the MCP tool, if not specified the function will check if any tools exist in the specified group.

.PARAMETER Group
The Group in which to check for the MCP tool(s).

.EXAMPLE
# test for the existence of a specific MCP tool by name from a default group
Test-PodeMcpTool -Name 'GreetPerson' -Group 'default'

.EXAMPLE
# test for the existence of any MCP tools in a specific group
Test-PodeMcpTool -Group 'custom'

.EXAMPLE
# test for the existence of a non-existent tool, which will return false
Test-PodeMcpTool -Name 'NonExistentTool'
#>
function Test-PodeMcpTool {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Group
    )

    $hasName = ![string]::IsNullOrEmpty($Name)
    $hasGroup = ![string]::IsNullOrEmpty($Group)

    # if no name or group, return true if any tools exist
    if (!$hasName -and !$hasGroup) {
        return $PodeContext.Server.Mcp.Tools.Count -gt 0
    }

    # if no group provided, return true if tool exists
    if (!$hasGroup) {
        return $PodeContext.Server.Mcp.Tools.ContainsKey($Name)
    }

    # if no name provided, return true if any tools in group
    if (!$hasName) {
        return $PodeContext.Server.Mcp.Groups.ContainsKey($Group) -and
        ($PodeContext.Server.Mcp.Groups[$Group].Tools.Count -gt 0)
    }

    # otherwise both provided, return true if tool exists in group
    return $PodeContext.Server.Mcp.Groups.ContainsKey($Group) -and
    ($PodeContext.Server.Mcp.Groups[$Group].Tools -icontains $Name) -and
    $PodeContext.Server.Mcp.Tools.ContainsKey($Name)
}

<#
.SYNOPSIS
Removes an MCP tool.

.DESCRIPTION
Removes an MCP tool in general, or from the specified group.

.PARAMETER Name
The Name of the MCP tool to remove.

.PARAMETER Group
The Group from which to remove the MCP tool.

.EXAMPLE
# remove a specific MCP tool from all groups, and the tool itself
Remove-PodeMcpTool -Name 'GreetPerson'

.EXAMPLE
# remove a specific MCP tool from a specific group only - but keep the tool itself in case it's in other groups
Remove-PodeMcpTool -Name 'GreetPerson' -Group 'custom'

.EXAMPLE
# attempt to remove a non-existent tool, which will do nothing
Remove-PodeMcpTool -Name 'NonExistentTool'
#>
function Remove-PodeMcpTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Group
    )

    # if the tool doesn't exist, do nothing
    if (!$PodeContext.Server.Mcp.Tools.ContainsKey($Name)) {
        return
    }

    # if no groups specified, get the groups the tool is in
    $hasGroups = ![string]::IsNullOrEmpty($Group)
    if (!$hasGroups) {
        $Group = $PodeContext.Server.Mcp.Tools[$Name].Groups
    }

    # remove the tool from each group
    foreach ($g in $Group) {
        if ($PodeContext.Server.Mcp.Groups.ContainsKey($g)) {
            $null = $PodeContext.Server.Mcp.Groups[$g].Tools.Remove($Name)
        }
    }

    # if no groups were specified then remove the tool entirely
    if (!$hasGroups) {
        $null = $PodeContext.Server.Mcp.Tools.Remove($Name)
    }

    # otherwise, keep the tool but remove the group(s) from its info
    else {
        $tool = $PodeContext.Server.Mcp.Tools[$Name]
        $tool.Groups = $tool.Groups | Where-Object { $_ -inotin $Group }
    }
}

<#
.SYNOPSIS
Updates an existing MCP tool.

.DESCRIPTION
Updates the properties of an existing MCP tool, including its description, scriptblock, and/or resetting the properties.

.PARAMETER Name
The Name of the MCP tool to update.

.PARAMETER Description
An optional new Description for the MCP tool.

.PARAMETER ScriptBlock
An optional new ScriptBlock for the MCP tool.

.PARAMETER ResetProperties
A switch to reset the Properties of the MCP tool, if a new ScriptBlock has changed the parameters which need to be supplied.

.PARAMETER PassThru
A switch parameter to return the updated MCP tool.

.EXAMPLE
# update the description of an existing MCP tool
Update-PodeMcpTool -Name 'GreetPerson' -Description 'Returns a random greeting to a person, updated description'

.EXAMPLE
# update the scriptblock of an existing MCP tool, and reset its properties
Update-PodeMcpTool -Name 'GreetPerson' -ScriptBlock {
    param(
        [string]$Name,
        [string]$Location
    )
    $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
    $greeting = Get-Random -InputObject $greetings
    return New-PodeMcpTextContent -Value "$($greeting), $($Name) from $($Location)! via the updated Pode MCP tool!"
} -ResetProperties
#>
function Update-PodeMcpTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $ResetProperties,

        [switch]
        $PassThru
    )

    # error if the tool doesn't exist
    if (!$PodeContext.Server.Mcp.Tools.ContainsKey($Name)) {
        # The MCP tool '$($Name)' does not exist
        throw ($PodeLocale.mcpToolDoesNotExistExceptionMessage -f $Name)
    }

    $tool = $PodeContext.Server.Mcp.Tools[$Name]

    # update tool description
    if ($PSBoundParameters.ContainsKey('Description')) {
        $tool.Description = $Description
    }

    # update tool scriptblock
    if ($PSBoundParameters.ContainsKey('ScriptBlock')) {
        $tool.ScriptBlock = $ScriptBlock
    }

    # reset tool properties if requested
    if ($ResetProperties) {
        $tool.Properties = @()
    }

    # return tool if requested
    if ($PassThru) {
        return $tool
    }
}

<#
.SYNOPSIS
Adds a new MCP tool group to the server.

.DESCRIPTION
Adds a new MCP tool group to the server, which can be used to organize tools into different categories.

.PARAMETER Name
The Name of the MCP tool group.

.PARAMETER Description
An optional brief Description for the MCP tool group.

.EXAMPLE
# add a new MCP tool group
Add-PodeMcpGroup -Name 'default' -Description 'The default group for MCP tools'
#>
function Add-PodeMcpGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description
    )

    if ($PodeContext.Server.Mcp.Groups.ContainsKey($Name)) {
        # The MCP tool group '$($Name)' already exists
        throw ($PodeLocale.mcpToolGroupAlreadyExistsExceptionMessage -f $Name)
    }

    $PodeContext.Server.Mcp.Groups[$Name] = @{
        Name        = $Name
        Description = $Description
        Tools       = @()
    }
}

<#
.SYNOPSIS
Removes an MCP tool group from the server.

.DESCRIPTION
Removes an MCP tool group from the server.

.PARAMETER Name
The Name of the MCP tool group to remove.

.EXAMPLE
# remove an MCP tool group
Remove-PodeMcpGroup -Name 'default'
#>
function Remove-PodeMcpGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # skip if group doesn't exist
    if (!$PodeContext.Server.Mcp.Groups.ContainsKey($Name)) {
        return
    }

    # remove the group from any tools that were in it
    foreach ($toolName in $PodeContext.Server.Mcp.Groups[$Name].Tools) {
        if ($PodeContext.Server.Mcp.Tools.ContainsKey($toolName)) {
            $tool = $PodeContext.Server.Mcp.Tools[$toolName]
            $tool.Groups = $tool.Groups | Where-Object { $_ -ne $Name }
        }
    }

    # remove the group
    $null = $PodeContext.Server.Mcp.Groups.Remove($Name)
}

<#
.SYNOPSIS
Retrieves an MCP tool group or groups.

.DESCRIPTION
Retrieves an MCP tool group or groups from the server.

.PARAMETER Name
The Name of the MCP tool group to retrieve. If not specified, all groups will be returned.

.EXAMPLE
# retrieve a specific MCP tool group by name
Get-PodeMcpGroup -Name 'default'
#>
function Get-PodeMcpGroup {
    [CmdletBinding()]
    [OutputType([hashtable])]
    [OutputType([hashtable[]])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    # if no name, return all groups
    if ([string]::IsNullOrEmpty($Name)) {
        return $PodeContext.Server.Mcp.Groups.Values
    }

    # otherwise, return specified group(s) if it exists
    $groups = @()
    foreach ($n in $Name) {
        if ($PodeContext.Server.Mcp.Groups.ContainsKey($n)) {
            $groups += $PodeContext.Server.Mcp.Groups[$n]
        }
    }

    return $groups
}

<#
.SYNOPSIS
Tests the existence of an MCP tool group.

.DESCRIPTION
Tests the existence of an MCP tool group.

.PARAMETER Name
The Name of the MCP tool group to test. If not specified, the function will return true if any groups exist.

.EXAMPLE
# test if a specific MCP tool group exists
Test-PodeMcpGroup -Name 'default'

.EXAMPLE
# test if any MCP tool groups exist
Test-PodeMcpGroup
#>
function Test-PodeMcpGroup {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $Name
    )

    # if no name, return true if any groups exist
    if ([string]::IsNullOrEmpty($Name)) {
        return $PodeContext.Server.Mcp.Groups.Count -gt 0
    }

    # otherwise, return true if specified group exists
    return $PodeContext.Server.Mcp.Groups.ContainsKey($Name)
}

<#
.SYNOPSIS
Clears all tools from an MCP tool group.

.DESCRIPTION
Clears all tools from an MCP tool group.

.PARAMETER Name
The Name of the MCP tool group to clear.

.EXAMPLE
# clear all tools from a specific MCP tool group
Clear-PodeMcpGroup -Name 'default'
#>
function Clear-PodeMcpGroup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    # if group exists, clear its tools
    if (!$PodeContext.Server.Mcp.Groups.ContainsKey($Name)) {
        return
    }

    # remove the group from any tools that were in it
    foreach ($toolName in $PodeContext.Server.Mcp.Groups[$Name].Tools) {
        if ($PodeContext.Server.Mcp.Tools.ContainsKey($toolName)) {
            $tool = $PodeContext.Server.Mcp.Tools[$toolName]
            $tool.Groups = $tool.Groups | Where-Object { $_ -ne $Name }
        }
    }

    # clear the tools from the group
    $PodeContext.Server.Mcp.Groups[$Name].Tools.Clear()
}

<#
.SYNOPSIS
Registers an MCP tool to a group.

.DESCRIPTION
Registers an MCP tool to a specified MCP tool group.

.PARAMETER Name
The Name of the MCP tool to register.

.PARAMETER Group
The Name of the MCP tool group to register the tool to.

.EXAMPLE
# register a specific MCP tool to a specific MCP tool group
Register-PodeMcpToolToGroup -Name 'tool1' -Group 'default'
#>
function Register-PodeMcpToolToGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Group
    )

    # error if group or tool doesn't exist
    if (!$PodeContext.Server.Mcp.Tools.ContainsKey($Name)) {
        # The MCP tool '$($Name)' does not exist
        throw ($PodeLocale.mcpToolDoesNotExistExceptionMessage -f $Name)
    }

    if (!$PodeContext.Server.Mcp.Groups.ContainsKey($Group)) {
        # The MCP tool group '$($Group)' does not exist
        throw ($PodeLocale.mcpToolGroupDoesNotExistExceptionMessage -f $Group)
    }

    # add the tool to the group if it's not already in it
    if ($PodeContext.Server.Mcp.Groups[$Group].Tools -inotcontains $Name) {
        $PodeContext.Server.Mcp.Groups[$Group].Tools += $Name
    }

    # add the group to the tool's info if it's not already in it
    $tool = $PodeContext.Server.Mcp.Tools[$Name]
    if ($tool.Groups -inotcontains $Group) {
        $tool.Groups += $Group
    }
}

<#
.SYNOPSIS
Unregisters an MCP tool from a group.

.DESCRIPTION
Unregisters an MCP tool from a specified MCP tool group.

.PARAMETER Name
The Name of the MCP tool to unregister.

.PARAMETER Group
The Name of the MCP tool group to unregister the tool from.

.EXAMPLE
# unregister a specific MCP tool from a specific MCP tool group
Unregister-PodeMcpToolFromGroup -Name 'tool1' -Group 'default'
#>
function Unregister-PodeMcpToolFromGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Group
    )

    # error if group or tool doesn't exist
    if (!$PodeContext.Server.Mcp.Tools.ContainsKey($Name)) {
        # The MCP tool '$($Name)' does not exist
        throw ($PodeLocale.mcpToolDoesNotExistExceptionMessage -f $Name)
    }

    if (!$PodeContext.Server.Mcp.Groups.ContainsKey($Group)) {
        # The MCP tool group '$($Group)' does not exist
        throw ($PodeLocale.mcpToolGroupDoesNotExistExceptionMessage -f $Group)
    }

    # remove the tool from the group if it's in it
    if ($PodeContext.Server.Mcp.Groups[$Group].Tools -icontains $Name) {
        $null = $PodeContext.Server.Mcp.Groups[$Group].Tools.Remove($Name)
    }

    # remove the group from the tool's info if it's in it
    $tool = $PodeContext.Server.Mcp.Tools[$Name]
    if ($tool.Groups -icontains $Group) {
        $null = $tool.Groups.Remove($Group)
    }
}