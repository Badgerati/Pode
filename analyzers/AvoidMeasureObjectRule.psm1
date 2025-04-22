function Measure-AvoidMeasureObjectRule {
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
        # Traverse the AST to find all instances of Measure-Object cmdlet
        $ScriptBlockAst.FindAll({
                param($Ast)
                $Ast -is [System.Management.Automation.Language.CommandAst] -and
                $Ast.CommandElements[0].Extent.Text -eq 'Measure-Object'
            }, $true) | ForEach-Object {
            $diagnostics += [PSCustomObject]@{
                Message    = "Avoid using 'Measure-Object' and use .Length or .Count properties instead."
                Extent     = $_.Extent
                RuleName   = 'AvoidMeasureObjectRule'
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

Export-ModuleMember -Function Measure-AvoidMeasureObjectRule