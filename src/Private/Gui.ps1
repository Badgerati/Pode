function Start-PodeGuiRunspace {
    # do nothing if gui not enabled, or running as serverless
    if (!$PodeContext.Server.Gui.Enabled -or
        $PodeContext.Server.IsServerless -or
        $PodeContext.Server.IsIIS -or
        $PodeContext.Server.IsHeroku) {
        return
    }

    $script = {
        try {
            # if there are multiple endpoints, flag warning we're only using the first - unless explicitly set
            if ($null -eq $PodeContext.Server.Gui.Endpoint) {
                if ($PodeContext.Server.Endpoints.Values.Count -gt 1) {
                    Write-PodeHost "Multiple endpoints defined, only the first will be used for the GUI" -ForegroundColor Yellow
                }
            }

            # get the endpoint on which we're currently listening, or use explicitly passed one
            $uri = (Get-PodeEndpointUrl -Endpoint $PodeContext.Server.Gui.Endpoint)

            # poll the server for a response
            $count = 0

            while ($true) {
                try {
                    Invoke-WebRequest -Method Get -Uri $uri -UseBasicParsing -ErrorAction Stop | Out-Null
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
                        throw "Failed to connect to URL: $($uri)"
                    }
                }
            }

            # import the WPF assembly
            [System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null
            [System.Reflection.Assembly]::LoadWithPartialName('PresentationCore') | Out-Null

            # Check for CefSharp
            $loadCef = [bool]([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName.StartsWith("CefSharp.Wpf,") })

            # setup the WPF XAML for the server
            # Check for CefSharp and used Chromium based WPF if Modules exists
            if ($loadCef) {
                $gui_browser = "
                <Window
                    xmlns=`"http://schemas.microsoft.com/winfx/2006/xaml/presentation`"
                    xmlns:wpf=`"clr-namespace:CefSharp.Wpf;assembly=CefSharp.Wpf`"
                    xmlns:x=`"http://schemas.microsoft.com/winfx/2006/xaml`"
                    Title=`"$($PodeContext.Server.Gui.Title)`"
                    Height=`"$($PodeContext.Server.Gui.Height)`"
                    Width=`"$($PodeContext.Server.Gui.Width)`"
                    ResizeMode=`"$($PodeContext.Server.Gui.ResizeMode)`"
                    WindowStartupLocation=`"CenterScreen`"
                    ShowInTaskbar = `"$($PodeContext.Server.Gui.ShowInTaskbar)`"
                    WindowStyle = `"$($PodeContext.Server.Gui.WindowStyle)`">
                        <Window.TaskbarItemInfo>
                            <TaskbarItemInfo />
                        </Window.TaskbarItemInfo>
                        <Border Grid.Row=`"1`" BorderBrush=`"Gray`" BorderThickness=`"0,1`">
                            <wpf:ChromiumWebBrowser x:Name=`"Browser`" Address=`"$uri`"/>
                        </Border>
                </Window>"
            }
            else {
                # Fall back to the IE based WPF Browser
                $gui_browser = "
                    <Window
                        xmlns=`"http://schemas.microsoft.com/winfx/2006/xaml/presentation`"
                        xmlns:x=`"http://schemas.microsoft.com/winfx/2006/xaml`"
                        Title=`"$($PodeContext.Server.Gui.Title)`"
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
            }

            # read in the XAML
            $reader = [System.Xml.XmlNodeReader]::new([xml]$gui_browser)
            $form = [Windows.Markup.XamlReader]::Load($reader)

            # set other options
            $form.TaskbarItemInfo.Description = $form.Title

            # add the icon to the form
            if (!(Test-PodeIsEmpty $PodeContext.Server.Gui.Icon)) {
                $icon = [Uri]::new($PodeContext.Server.Gui.Icon)
                $form.Icon = [Windows.Media.Imaging.BitmapFrame]::Create($icon)
            }

            # set the state of the window onload
            if (!(Test-PodeIsEmpty $PodeContext.Server.Gui.WindowState)) {
                $form.WindowState = $PodeContext.Server.Gui.WindowState
            }

            # get the browser object from XAML and navigate to base page if Cef is not loaded
            if (!$loadCef) {
                $form.FindName("WebBrowser").Navigate($uri)
            }

            # display the form
            $form.ShowDialog() | Out-Null
            Start-Sleep -Seconds 1
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
        finally {
            # invoke the cancellation token to close the server
            $PodeContext.Tokens.Cancellation.Cancel()
        }
    }

    Add-PodeRunspace -Type Gui -ScriptBlock $script
}