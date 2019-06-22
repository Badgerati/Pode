function Start-PodeGuiRunspace
{
    # do nothing if gui not enabled, or running as serverless
    if (!$PodeContext.Server.Gui.Enabled -or $PodeContext.Server.IsServerless) {
        return
    }

    $script = {
        try
        {
            # if there are multiple endpoints, flag warning we're only using the first - unless explicitly set
            if ($null -eq $PodeContext.Server.Gui.Endpoint)
            {
                if (($PodeContext.Server.Endpoints | Measure-Object).Count -gt 1) {
                    Write-Host "Multiple endpoints defined, only the first will be used for the GUI" -ForegroundColor Yellow
                }
            }

            # get the endpoint on which we're currently listening, or use explicitly passed one
            $endpoint = (Get-PodeEndpointUrl -Endpoint $PodeContext.Server.Gui.Endpoint)

            # poll the server for a response
            $count = 0

            while ($true) {
                try {
                    Invoke-WebRequest -Method Get -Uri $endpoint -UseBasicParsing -ErrorAction Stop | Out-Null
                    if (!$?) {
                        throw
                    }

                    break
                }
                catch {
                    $count++
                    if ($count -le 50) {
                        Start-Sleep -Milliseconds 200
                    }
                    else {
                        throw "Failed to connect to URL: $($endpoint)"
                    }
                }
            }

            # import the WPF assembly
            [System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null
            [System.Reflection.Assembly]::LoadWithPartialName('PresentationCore') | Out-Null

            # setup the WPF XAML for the server
            $gui_browser = "
                <Window
                    xmlns=`"http://schemas.microsoft.com/winfx/2006/xaml/presentation`"
                    xmlns:x=`"http://schemas.microsoft.com/winfx/2006/xaml`"
                    Title=`"$($PodeContext.Server.Gui.Name)`"
                    Height=`"$($PodeContext.Server.Gui.Height)`"
                    Width=`"$($PodeContext.Server.Gui.Width)`"
                    ResizeMode=`"$($PodeContext.Server.Gui.ResizeMode)`"
                    WindowStartupLocation=`"CenterScreen`"
                    ShowInTaskbar = `"$($PodeContext.Server.Gui.ShowInTaskbar)`"
                    WindowStyle = `"$($PodeContext.Server.Gui.WindowStyle)`">
                        <Window.TaskbarItemInfo>
                            <TaskbarItemInfo />
                        </Window.TaskbarItemInfo>
                        <WebBrowser Name=`"WebBrowser`"></WebBrowser>
                </Window>"

            # read in the XAML
            $reader = [System.Xml.XmlNodeReader]::new([xml]$gui_browser)
            $form = [Windows.Markup.XamlReader]::Load($reader)

            # set other options
            $form.TaskbarItemInfo.Description = $form.Title

            # add the icon to the form
            if (!(Test-Empty $PodeContext.Server.Gui.Icon)) {
                $icon = [Uri]::new($PodeContext.Server.Gui.Icon)
                $form.Icon = [Windows.Media.Imaging.BitmapFrame]::Create($icon)
            }

            # set the state of the window onload
            if (!(Test-Empty $PodeContext.Server.Gui.State)) {
                $form.WindowState = $PodeContext.Server.Gui.State
            }

            # get the browser object from XAML and navigate to base page
            $form.FindName("WebBrowser").Navigate($endpoint)

            # display the form
            $form.ShowDialog() | Out-Null
            Start-Sleep -Seconds 1
        }
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
        finally {
            # invoke the cancellation token to close the server
            $PodeContext.Tokens.Cancellation.Cancel()
        }
    }

    Add-PodeRunspace -Type 'Gui' -ScriptBlock $script
}

function Gui
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('o')]
        [hashtable]
        $Options
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'gui' -ThrowError

    # only valid for Windows PowerShell
    if (Test-IsPSCore) {
        throw 'The gui function is currently unavailable for PS Core, and only works for Windows PowerShell'
    }

    # enable the gui and set it's title/name
    $PodeContext.Server.Gui.Enabled = $true
    $PodeContext.Server.Gui.Name = $Name

    # coalesce the options
    $Options = (coalesce $Options @{})

    # set the window's icon path
    if (![string]::IsNullOrWhiteSpace($Options.Icon)) {
        $PodeContext.Server.Gui.Icon = (Resolve-Path $Options.Icon).Path
        if (!(Test-Path $PodeContext.Server.Gui.Icon)) {
            throw "Path to icon for GUI does not exist: $($PodeContext.Server.Gui.Icon)"
        }
    }

    # display the app in the taskbar?
    $PodeContext.Server.Gui.ShowInTaskbar = (coalesce $Options.ShowInTaskbar $true)

    # set the window's state
    $states = @('Normal', 'Maximized', 'Minimized')
    $PodeContext.Server.Gui.State = (coalesce $Options.State 'Normal')
    if ($states -inotcontains $PodeContext.Server.Gui.State) {
        throw "Invalid GUI window state supplied, should be blank or one of $($states -join ' / ')"
    }

    # set the window's style
    $styles = @('None', 'SingleBorderWindow', 'ThreeDBorderWindow', 'ToolWindow')
    $PodeContext.Server.Gui.WindowStyle = (coalesce $Options.WindowStyle 'SingleBorderWindow')
    if ($styles -inotcontains $PodeContext.Server.Gui.WindowStyle) {
        throw "Invalid GUI window style supplied, should be blank or one of $($styles -join ' / ')"
    }

    # set the height of the window
    $PodeContext.Server.Gui.Height = (coalesce ([int]$Options.Height) 0)
    if ($PodeContext.Server.Gui.Height -le 0) {
        $PodeContext.Server.Gui.Height = 'auto'
    }

    # set the width of the window
    $PodeContext.Server.Gui.Width = (coalesce ([int]$Options.Width) 0)
    if ($PodeContext.Server.Gui.Width -le 0) {
        $PodeContext.Server.Gui.Width = 'auto'
    }

    # set the resize mode of the window
    $modes = @('CanResize', 'CanMinimize', 'NoResize')
    $PodeContext.Server.Gui.ResizeMode = (coalesce $Options.ResizeMode 'CanResize')
    if ($modes -inotcontains $PodeContext.Server.Gui.ResizeMode) {
        throw "Invalid GUI window resize mode supplied, should be blank or one of $($modes -join ' / ')"
    }

    # set the gui to use a specific listener
    $PodeContext.Server.Gui.ListenName = $Options.ListenName

    if (!(Test-Empty $PodeContext.Server.Gui.ListenName)) {
        $found = ($PodeContext.Server.Endpoints | Where-Object {
            $_.Name -eq $PodeContext.Server.Gui.ListenName
        } | Select-Object -First 1)

        if ($null -eq $found) {
            throw "Listen endpoint with name '$($Name)' does not exist"
        }

        $PodeContext.Server.Gui.Endpoint = $found
    }
}