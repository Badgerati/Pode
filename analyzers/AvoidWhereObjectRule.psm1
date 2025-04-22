function Measure-AvoidWhereObjectRule {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidForEachObjectRule', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '')]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    # Initialize an empty array to collect diagnostic records
    $diagnostics = @()

    try {
        # Traverse the AST to find all instances of Where-Object cmdlet
        $ScriptBlockAst.FindAll({
                param($Ast)
                $Ast -is [System.Management.Automation.Language.CommandAst] -and
                $Ast.CommandElements[0].Extent.Text -eq 'Where-Object'
            }, $true) | ForEach-Object {
            $diagnostics += [PSCustomObject]@{
                Message    = "Avoid using 'Where-Object' and use 'foreach() { if() }' instead."
                Extent     = $_.Extent
                RuleName   = 'AvoidWhereObjectRule'
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

Export-ModuleMember -Function Measure-AvoidWhereObjectRule