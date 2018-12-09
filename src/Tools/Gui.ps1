function Start-GuiRunspace
{
    # do nothing if gui not enabled
    if (!$PodeSession.Server.Gui.Enabled) {
        return
    }

    $script = {
        try
        {
            # get the endpoint on which we're currently listening
            $protocol = (iftet $PodeSession.Server.IP.Ssl 'https' 'http')

            # grab the port
            $port = $PodeSession.Server.IP.Port
            if ($port -eq 0) {
                $port = (iftet $PodeSession.Server.IP.Ssl 8443 8080)
            }

            $endpoint = "$($protocol)://$($PodeSession.Server.IP.Name):$($port)"

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
                    Title=`"$($PodeSession.Server.Gui.Name)`"
                    WindowStartupLocation=`"CenterScreen`"
                    ShowInTaskbar = `"$($PodeSession.Server.Gui.ShowInTaskbar)`"
                    WindowStyle = `"$($PodeSession.Server.Gui.WindowStyle)`">
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
            if (!(Test-Empty $PodeSession.Server.Gui.Icon)) {
                $icon = [Uri]::new($PodeSession.Server.Gui.Icon)
                $form.Icon = [Windows.Media.Imaging.BitmapFrame]::Create($icon)
            }

            # set the state of the window onload
            if (!(Test-Empty $PodeSession.Server.Gui.State)) {
                $form.WindowState = $PodeSession.Server.Gui.State
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
            $PodeSession.Tokens.Cancellation.Cancel()
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

    # only valid for Windows PowerShell
    if (Test-IsPSCore) {
        throw 'The gui function is currently unavailable for PS Core, and only works for Windows PowerShell'
    }

    # enable the gui
    $PodeSession.Server.Gui.Enabled = $true
    $PodeSession.Server.Gui.Name = $Name

    # if we have options, set them up
    if (!(Test-Empty $Options)) {
        if (!(Test-Empty $Options.Icon)) {
            $PodeSession.Server.Gui['Icon'] = (Resolve-Path $Options.Icon).Path
        }

        if (!(Test-Empty $Options.ShowInTaskbar)) {
            $PodeSession.Server.Gui['ShowInTaskbar'] = $Options.ShowInTaskbar
        }

        if (!(Test-Empty $Options.State)) {
            $PodeSession.Server.Gui['State'] = $Options.State
        }

        if (!(Test-Empty $Options.WindowStyle)) {
            $PodeSession.Server.Gui['WindowStyle'] = $Options.WindowStyle
        }
    }

    # validate the settings
    $icon = $PodeSession.Server.Gui.Icon
    if (!(Test-Empty $icon) -and !(Test-Path $icon)) {
        throw "Path to icon for GUI does not exist: $($icon)"
    }

    $state = $PodeSession.Server.Gui.State
    $states = @('Normal', 'Maximized', 'Minimized')
    if (!(Test-Empty $state) -and ($states -inotcontains $state)) {
        throw "Invalid GUI window state supplied, should be blank or one of $($states -join ' / ')"
    }

    $style = $PodeSession.Server.Gui.WindowStyle
    $styles = @('None', 'SingleBorderWindow', 'ThreeDBorderWindow', 'ToolWindow')
    if (!(Test-Empty $style) -and ($styles -inotcontains $style)) {
        throw "Invalid GUI window style supplied, should be blank or one of $($styles -join ' / ')"
    }
}