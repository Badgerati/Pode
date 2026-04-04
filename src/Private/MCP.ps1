function Test-PodeMcpRequest {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Group
    )

    # check if the group exists, if not return an error
    if (!(Test-PodeMcpGroup -Name $Group)) {
        Write-PodeMcpErrorResponse -Message "Group '$($Group)' not found" -Type InternalError
        return $false
    }

    # ensure request has valid jsonrpc version
    if ($WebEvent.Data['jsonrpc'] -ne '2.0') {
        Write-PodeMcpErrorResponse -Message 'Invalid JSON-RPC version' -Type InvalidRequest
        return $false
    }

    # do we have a MCP method, error if not
    $method = $WebEvent.Data['method']
    if ([string]::IsNullOrEmpty($method)) {
        Write-PodeMcpErrorResponse -Message 'Missing method' -Type InvalidRequest
        return $false
    }

    # for non-notification methods, ensure we have an ID
    if ([string]::IsNullOrEmpty($WebEvent.Data['id']) -and ($method -inotlike 'notifications/*')) {
        Write-PodeMcpErrorResponse -Message 'Missing ID for non-notification method' -Type InvalidRequest
        return $false
    }

    return $true
}

# https://www.jsonrpc.org/specification
function Write-PodeMcpErrorResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ParseError', 'InvalidRequest', 'MethodNotFound', 'InvalidParams', 'InternalError')]
        [string]
        $Type,

        [Parameter()]
        [int]
        $StatusCode = 400
    )

    # determine the error code
    $errCode = switch ($Type.ToLowerInvariant()) {
        'parseerror' { -32700 }
        'invalidrequest' { -32600 }
        'methodnotfound' { -32601 }
        'invalidparams' { -32602 }
        'internalerror' { -32603 }
    }

    # write the response
    $response = @{
        jsonrpc = '2.0'
        id      = $WebEvent.Data['id']
        error   = @{
            code    = $errCode
            message = $Message
        }
    }

    Write-PodeJsonResponse -Value $response -StatusCode $StatusCode
}

# https://www.jsonrpc.org/specification
function Write-PodeMcpSuccessResponse {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]
        $Result = $null
    )

    # if the result is null, return a 202 Accepted with no content
    if ($null -eq $Result) {
        Set-PodeResponseStatus -Code 202
        return
    }

    # otherwise, return a 200 OK with the result
    $response = @{
        jsonrpc = '2.0'
        id      = $WebEvent.Data['id']
        result  = $Result
    }

    Write-PodeJsonResponse -Value $response
}

function Invoke-PodeMcpInitialize {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [Parameter()]
        [string]
        $ServerVersion
    )

    if ([string]::IsNullOrEmpty($ServerVersion)) {
        $ServerVersion = $PodeContext.Server.Version
    }

    return @{
        protocolVersion = '2025-11-25'
        capabilities    = @{
            tools = @{
                listChanged = $false
            }
        }
        serverInfo      = @{
            name    = $ServerName
            version = $ServerVersion
        }
    }
}

function Invoke-PodeMcpToolList {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Group
    )

    # build the tools content
    $content = @{
        tools = @()
    }

    # loop through the tools in the group and add them to the content
    foreach ($toolName in $PodeContext.Server.Mcp.Groups[$Group].Tools) {
        $tool = $PodeContext.Server.Mcp.Tools[$toolName]

        $content.tools += @{
            name        = $tool.Name
            description = $tool.Description
            inputSchema = New-PodeJsonSchemaObject -Property $tool.Properties
        }
    }

    return $content
}

function Invoke-PodeMcpToolCall {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Group
    )

    # get tool name and arguments
    $toolName = $WebEvent.Data['params']['name']
    $toolArgs = $WebEvent.Data['params']['arguments']

    # check if the tool exists, if not return an error
    if (!(Test-PodeMcpTool -Group $Group -Name $toolName)) {
        Write-PodeMcpErrorResponse -Message "Tool '$($toolName)' not found in group '$($Group)'" -Type InvalidParams
        return $null
    }

    $tool = $PodeContext.Server.Mcp.Tools[$toolName]

    # attempt to invoke the scriptblock, passing in the arguments
    try {
        [hashtable[]]$result = Invoke-PodeScriptBlock -ScriptBlock $tool.ScriptBlock -Arguments $toolArgs -Scoped -Splat -Return
    }
    catch {
        Write-PodeMcpErrorResponse -Message "Error invoking tool '$($toolName)' in group '$($Group)': $($_.Exception.Message)" -Type InternalError -StatusCode 500
        $_ | Write-PodeErrorLog
        return $null
    }

    return @{
        content = $result
        isError = $false
    }
}

function Add-PodeMcpToolAutoSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Tool,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    # do nothing if we don't have any parameters
    if (($null -eq $ScriptBlock.Ast.ParamBlock) -or ($ScriptBlock.Ast.ParamBlock.Parameters.Count -eq 0)) {
        return
    }

    foreach ($param in $ScriptBlock.Ast.ParamBlock.Parameters) {
        # get values from param attributes, such as Mandatory, HelpMessage, and also any Validate attributes
        $isMandatory = $false
        $helpMessage = $null
        $dontShow = $false
        $validRangeMin = $null
        $validRangeMax = $null
        $validSet = $null
        $validLengthMin = $null
        $validLengthMax = $null
        $validCountMin = $null
        $validCountMax = $null

        foreach ($attr in $param.Attributes) {
            switch ($attr.TypeName.FullName.ToLowerInvariant()) {
                'parameter' {
                    foreach ($arg in $attr.NamedArguments) {
                        switch ($arg.ArgumentName.ToLowerInvariant()) {
                            'mandatory' {
                                $isMandatory = $arg.Argument.Extent.Text -eq '$true'
                            }
                            'helpmessage' {
                                $helpMessage = $arg.Argument.Value.ToString()
                            }
                            'dontshow' {
                                $dontShow = $arg.Argument.Extent.Text -eq '$true'
                            }
                        }
                    }
                }

                'validaterange' {
                    $validRangeMin = $attr.PositionalArguments[0].Value
                    $validRangeMax = $attr.PositionalArguments[1].Value
                }

                'validateset' {
                    $validSet = $attr.PositionalArguments.Value
                }

                'validatelength' {
                    $validLengthMin = $attr.PositionalArguments[0].Value
                    $validLengthMax = $attr.PositionalArguments[1].Value
                }

                'validatecount' {
                    $validCountMin = $attr.PositionalArguments[0].Value
                    $validCountMax = $attr.PositionalArguments[1].Value
                }
            }
        }

        # if don't show is set, skip this parameter
        if ($dontShow) {
            continue
        }

        # build the property definition for parameter, based on the parameter type
        $paramName = $param.Name.Extent.Text.TrimStart('$')
        $definition = $null

        # build params for base types
        $_params = @{}
        if (($null -ne $validRangeMin) -or ($null -ne $validRangeMax)) {
            $_params.Minimum = $validRangeMin
            $_params.Maximum = $validRangeMax
        }
        if (($null -ne $validLengthMin) -or ($null -ne $validLengthMax)) {
            $_params.MinLength = $validLengthMin
            $_params.MaxLength = $validLengthMax
        }
        if ($null -ne $validSet) {
            $_params.Enum = $validSet
        }

        # what is the base type
        $type = $param.StaticType
        if ($param.StaticType.IsArray) {
            $type = $param.StaticType.GetElementType()
        }
        else {
            $_params.Description = $helpMessage
        }

        switch ($type) {
            'string' {
                $definition = New-PodeJsonSchemaString @_params
            }

            { $_ -iin 'int', 'long' } {
                $definition = New-PodeJsonSchemaInteger @_params
            }

            { $_ -iin 'double', 'float' } {
                $definition = New-PodeJsonSchemaNumber @_params
            }

            'bool' {
                $definition = New-PodeJsonSchemaBoolean @_params
            }

            default {
                # Unsupported parameter type '$($type)' for parameter '$($paramName)' in tool '$($Tool.Name)'. Auto schema generation only supports string, int, long, double, float, and bool types.
                throw ($PodeLocale.mcpToolAutoSchemaUnsupportedParameterTypeExceptionMessage -f $type, $paramName, $Tool.Name)
            }
        }

        # if it's an array, we need to wrap the definition in an array definition
        if ($param.StaticType.IsArray) {
            $_params = @{
                Item        = $definition
                Description = $helpMessage
            }

            if (($null -ne $validCountMin) -or ($null -ne $validCountMax)) {
                $_params.MinItems = $validCountMin
                $_params.MaxItems = $validCountMax
            }

            $definition = New-PodeJsonSchemaArray @_params
        }

        # add the property to the tool's properties
        Add-PodeMcpToolProperty -Tool $Tool -Name $paramName -Required:$isMandatory -Definition $definition
    }
}