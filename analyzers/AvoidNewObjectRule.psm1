function Measure-AvoidNewObjectRule {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    # Initialize an empty array to collect diagnostic records
    $diagnostics = @()

    try {
        # Traverse the AST to find all instances of New-Object cmdlet
        $ScriptBlockAst.FindAll({
                param($Ast)
                $Ast -is [System.Management.Automation.Language.CommandAst] -and
                $Ast.CommandElements[0].Extent.Text -eq 'New-Object'
            }, $true) | ForEach-Object {
            $diagnostics += [PSCustomObject]@{
                Message    = "Avoid using 'New-Object' and use '::new()' instead."
                Extent     = $_.Extent
                RuleName   = 'AvoidNewObjectRule'
                Severity   = 'Warning'
                ScriptName = $FileName
            }
        }

        # Return the diagnostic records
        return $diagnostics
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

Export-ModuleMember -Function Measure-AvoidNewObjectRule