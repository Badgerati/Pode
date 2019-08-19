# import pslambda if it's there
if ($null -ne (Get-Module -Name PSLambda -ListAvailable)) {
    Import-Module -Name PSLambda -RequiredVersion 0.2.0 -Force
    $env:ASPNETCORE_SUPPRESSSTATUSMESSAGES = 'true'
}

# add system.web, as some machines seem to not have it pre-loaded
Add-Type -AssemblyName System.Web

# add pode task class
Add-Type @"
    using System.Threading.Tasks;
    using System.Threading;
    using System.Collections;

    public sealed class PodeTask
    {
        public static Task CreateDelayTask(CancellationToken token)
        {
            var task = new Task(() => {
                try {
                    var itask = Task.Delay(30000, token);
                    itask.Wait();
                }
                catch { }
            });

            return task;
        }

        public static Task CreateContextTask(Stack contexts)
        {
            var task = new Task<object>(() => {
                while (true) {
                    lock(contexts) {
                        if (contexts.Count > 0) {
                            return contexts.Pop();
                        }
                    }

                    Thread.Sleep(100);
                }
            });

            return task;
        }
    }
"@

# import everything if in a runspace
if ($PODE_SCOPE_RUNSPACE) {
    $sysfuncs = Get-ChildItem Function:
}

# load private functions
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
Get-ChildItem "$($root)/Private/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# only import public functions if not in a runspace
if (!$PODE_SCOPE_RUNSPACE) {
    $sysfuncs = Get-ChildItem Function:
}

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)