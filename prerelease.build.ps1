[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param (
    [Parameter(Mandatory)]
    [string]$PodeVersion,

    [Parameter(Mandatory)]
    [string]$PreReleaseType,

    [Parameter()]
    [int[]]$ExcludePRs,

    [Parameter()]
    [switch]$Force
)


Add-BuildTask UpdateDevelop {
    git fetch upstream
    git checkout develop

    if (-not $Force) {
        $confirmation = Read-Host "⚠️ WARNING: This action will reset and force push 'develop' to match upstream. This is irreversible! Type 'y' to proceed or 'n' to cancel."
    }

    if ($confirmation -eq 'y' -or $Force) {
        git reset --hard upstream/develop
        git push origin develop --force
    }
    else {
        Write-Warning 'Skipping reset and force push.'
    }
}


Add-BuildTask CleanBranch Delete-ExistingBranch, Create-NewBranch, Create-VersionJson, Commit-VersionJson, {}


Add-BuildTask Delete-ExistingBranch UpdateDevelop, {
    if (git branch --list $PreReleaseType) {
        git branch -D $PreReleaseType
    }
}

Add-BuildTask Create-NewBranch Delete-ExistingBranch, {
    git checkout -b $PreReleaseType origin/develop
}

Add-BuildTask Create-VersionJson Create-NewBranch, {
    $VersionData = @{
        Version    = $PodeVersion
        Prerelease = $PreReleaseType
    } | ConvertTo-Json -Depth 2

    Set-Content -Path './Version.json' -Value $VersionData
}

Add-BuildTask Commit-VersionJson Create-VersionJson, {
    git add  './Version.json'
    git commit -m "Set Pode version to $PodeVersion-$PreReleaseType"
}

Add-BuildTask ProcessPRs Commit-VersionJson, {
    $prs = gh pr list --repo Badgerati/Pode --search 'draft:false' --json 'number,title,url,mergeStateStatus' | ConvertFrom-Json
    $mainPr = @($prs.Where({ $_.number -eq '1513' }))
    if ($ExcludePRs) {
        $prs = $prs | Where-Object { $_.number -notin $ExcludePRs }
    }
    $mainPr += $prs
    $prs = $mainPr
    foreach ($pr in $prs) {
        if ($pr.mergeStateStatus -ne 'CLEAN') {
            Write-Output "Skipping PR #$($pr.number): Merge state $($pr.mergeStateStatus)"
            continue
        }

        git fetch upstream pull/$($pr.number)/head:pr-$($pr.number)

        do {
            $mergeResult = git merge --squash pr-$($pr.number) 2>&1
            Write-Output $mergeResult
            $mergeExitCode = $LASTEXITCODE
            if ($mergeExitCode -ne 0) {
                Write-Output "❌ Merge failed for PR #$($pr.number). Choose an option: (R)etry after fixing, (M)anually resolve,(A)utomerge PodeLocale or (Q)uit the process."
                do {
                    $choice = Read-Host
                    if ($choice -eq 'q') { exit 1 }
                    if ($choice -eq 'm') { Read-Host '🛠️ Resolve the issue manually, then press Enter to retry the merge.'; $mergeExitCode = 0 }
                    if ($choice -eq 'a') {
                        Write-Output "❌ Merge failed for PR #$($pr.number). Attempting auto-merge for language files..."

                        # Auto-merge conflicts for language files in ./src/Locales/*
                        git diff --name-only --diff-filter=U ./src/Locales/ | ForEach-Object {
                        (Get-Content $_) -replace '<<<<<<< HEAD', '' -replace '=======', '' -replace ">>>>>>> pr-$($pr.number)" | Set-Content $_
                        }

                        # Call the Sort-LanguageFiles task
                        Invoke-Build Sort-LanguageFiles

                        # Mark them as resolved
                        git add ./src/Locales/*
                        Write-Output '✅ Language files auto-merged.'
                    }
                } until ('q', 'm', 'r' -contains $choice)
            }
        }
        while ($mergeExitCode -ne 0)

        # Run tests
        $testResultsPath = "$PSScriptRoot\testResults.xml"
        if (Test-Path $testResultsPath) { Remove-Item $testResultsPath }

        $testArgs = @(#'-NoExit',
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-Command', "`$Host.UI.RawUI.WindowTitle = '$customTitle'; Invoke-Build test"
        )

        do {
            $testProcess = Start-Process -FilePath 'pwsh.exe' -ArgumentList $testArgs -PassThru -WindowStyle Normal
            Write-Output "⏳ Running Pester tests for PR #$($pr.number)... Please wait."

            # Display a progress indicator while waiting for tests to complete
            while (!$testProcess.HasExited) {
                Start-Sleep -Seconds 10
                Write-Host '.' -NoNewline
            }
            Write-Host ''  # Move to a new line after completion

            # Abort if tests fail
            if ($testProcess.ExitCode -ne 0) {
                Write-Output "❌ Pester tests failed for PR #$prNumber (Exit Code: $($testProcess.ExitCode)). (R)etry running tests or (Q)uit the process?"
                do {
                    $choice = Read-Host
                    if ($choice -eq 'q') { exit 1 }
                    if ($choice -eq 'r') { Read-Host '🔄 Tests failed. Resolve the issue and press Enter to retry.' }
                } until ('q' , 'r' -contains $choice)
            }
        } until ($testProcess.ExitCode -eq 0)

        # Verify test results
        [xml]$testResults = Get-Content $testResultsPath
        if ([int]$testResults.'test-results'.failures -gt 0) {
            Write-Output "Tests failed for PR #$($pr.number). Aborting."
            exit 1
        }

        # Commit the PR merge with a formatted message and check for errors
        Write-Output "Committing merge for PR #$prNumber..."
        do {
            git commit -m "PR $prNumber $prTitle $prUrl"
            $commitExitCode = $LASTEXITCODE
            if ($commitExitCode -ne 0) {
                Write-Output "Commit failed for PR #$($pr.number). (R)etry/(Q)uit?"
                $choice = Read-Host
                if ($choice -eq 'q') { exit 1 }
                else { Read-Host '🛠️ Fix the commit issue manually, then press Enter to retry the commit.' }
            }
            else {
                Write-Output "✅ Commit successful for PR #$prNumber"
            }
        }
        while ($commitExitCode -ne 0)
    }

    Write-Output '✅ All PRs processed successfully!'
}


Add-BuildTask Sort-LanguageFiles {
    $localePath = './src/Locales'
    $files = Get-ChildItem -Path $localePath -Filter 'Pode.psd1' -Recurse

    foreach ($file in $files) {
        Write-Host "Processing file: $($file.FullName)"

        $messages = Import-PowerShellDataFile -Path $file.FullName

        $sortedKeys = $messages.Keys | Sort-Object

        $exceptionMessages = [ordered]@{}
        $generalMessages = [ordered]@{}

        foreach ($key in $sortedKeys) {
            if ($key -match 'ExceptionMessage$') {
                $exceptionMessages[$key] = $messages[$key]
            }
            else {
                $generalMessages[$key] = $messages[$key]
            }
        }

        $maxLength = ($sortedKeys | Measure-Object -Property Length -Maximum).Maximum + 1

        $lines = @()
        $lines += '@{'
        $lines += '    # -------------------------------'
        $lines += '    # Exception Messages'
        $lines += '    # -------------------------------'

        foreach ($key in $exceptionMessages.Keys) {
            $padding = ' ' * ($maxLength - $key.Length)
            $escapedValue = $exceptionMessages[$key].Replace("'", "''")
            $lines += "    $key$padding= '$escapedValue'"
        }

        $lines += ''
        $lines += '    # -------------------------------'
        $lines += '    # General Messages'
        $lines += '    # -------------------------------'

        foreach ($key in $generalMessages.Keys) {
            $padding = ' ' * ($maxLength - $key.Length)
            $escapedValue = $generalMessages[$key].Replace("'", "''")
            $lines += "    $key$padding= '$escapedValue'"
        }

        $lines += '}'

        # Explicitly write CRLF endings
        [System.IO.File]::WriteAllText($file.FullName, ($lines -join "`r`n") + "`r`n", [System.Text.UTF8Encoding]::new($false))

        Write-Host "Updated file: $($file.FullName)"
    }
}
# Default task
Add-BuildTask Default ProcessPRs
