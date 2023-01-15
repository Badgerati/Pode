# File Watchers

Creating a File Watcher lets you monitor for file changes at a given path. You can specify the [event](#events) to monitor (Created, Changed, etc.), and the attributes to use to trigger events (LastWrite, Size, etc.).

File Watcher paths can be literal or relative, and they can also support [parameters](#parameters) similar to Routes (ie: `C:/Websites/:site`)

??? note
    Under the hood the File Watcher uses the `System.IO.FileSystemWatcher` class, however the version used is an improved version from [GitHub](https://github.com/petermeinl/LeanWork.IO.FileSystem.Watcher) with further additional tweaks.

!!! info
    The File Watchers have been tested on Windows and Unix systems, as well as UNC paths from Windows and Azure Storage Account file shares. The File Watcher will not work on WSL.

## Create a File Watcher

You can create a File Watcher using [`Add-PodeFileWatcher`](../../Functions/FileWatchers/Add-PodeFileWatcher), this will let you specify a path to a directory to monitor and a script to invoke whenever an event is observed:

```powershell
Add-PodeFileWatcher -Path 'C:/websites' -ScriptBlock {
    "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
}
```

By default the above will monitor every file, and in every subdirectory, at `C:/websites`. It will also monitor files for the following `-EventName`: Created, Changed, Deleted, and Renamed. These events will be triggered observing the following `-NotifyFilter`: FileName, DirectoryName, LastWrite, CreationTime. Whenever a file event is observed the `-ScriptBlock` is triggered, and in the case of the above it will simply output the event to the console.

The `$FileEvent` variable works in a similar fashion to `$WebEvent`, and is detailed [below](#file-event).

!!! note
    When a File Watcher is created, it will be created with a random name. You can use a specific name by supplying the `-Name` parameter during creation. If you don't need a specific name, but you want to know the random name used, you can use the `-PassThru` switch to return the File Watcher object created.

### File Event

When an event is triggered, and the File Watcher's `-ScriptBlock` is invoked, a `$FileEvent` variable will be created and accessible from within the scriptblock.

```powershell
Add-PodeFileWatcher -Path 'C:/websites' -ScriptBlock {
    $FileEvent | Out-Default
}
```

The `$FileEvent` variable contains the following properties:

| Name | Type | Description |
| ---- | ---- | ----------- |
| FullPath | string | The full path to the file that triggered that event |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` |
| Name | string | The name of the file that triggered the event |
| Old | hashtable | When the event Type is "Renamed", this will contain the Name and FullPath for the previous name of the renamed file |
| Parameters | hashtable | Contains the parsed parameter values from the File Watcher#s path |
| Timestamp | datetime | The current date and time of the event |
| Type | PodeFileWatcherChangeType | The type of event that has been triggered |

### Events

The File Watcher can monitor a number of events, which can be specified by using the `-EventName` parameter. When you create a File Watcher without passing `-EventName`, a File Watcher will be created using events Changed, Created, Deleted and Renamed by default.

!!! tip
    There is a special event name of `*` which will create a File Watcher using every event type.

#### Changed

A File Watcher that triggers on the Changed `-EventName` will call the defined `-ScriptBlock` whenever a file is changed. When then scriptblock in invoked, the `$FileEvent` base Name/FullPath properties will be the Name/FullPath of the changed file.

```powershell
Add-PodeFileWatcher -EventName Changed -Path 'C:/websites' -ScriptBlock {
    # the Type will be set to "Changed"
    $FileEvent.Type | Out-Default

    # file name and path
    $FileEvent.Name | Out-Default
    $FileEvent.FullPath | Out-Default
}
```

#### Created

A File Watcher that triggers on the Created `-EventName` will call the defined `-ScriptBlock` whenever a file is created. When then scriptblock in invoked, the `$FileEvent` base Name/FullPath properties will be the Name/FullPath of the created file.

```powershell
Add-PodeFileWatcher -EventName Created -Path 'C:/websites' -ScriptBlock {
    # the Type will be set to "Created"
    $FileEvent.Type | Out-Default

    # file name and path
    $FileEvent.Name | Out-Default
    $FileEvent.FullPath | Out-Default
}
```

#### Deleted

A File Watcher that triggers on the Deleted `-EventName` will call the defined `-ScriptBlock` whenever a file is deleted. When then scriptblock in invoked, the `$FileEvent` base Name/FullPath properties will be the Name/FullPath of the deleted file.

```powershell
Add-PodeFileWatcher -EventName Deleted -Path 'C:/websites' -ScriptBlock {
    # the Type will be set to "Deleted"
    $FileEvent.Type | Out-Default

    # file name and path
    $FileEvent.Name | Out-Default
    $FileEvent.FullPath | Out-Default
}
```

#### Existed

A File Watcher that triggers on the Existed `-EventName` will call the defined `-ScriptBlock` on server start for every file that currently exists in the defined `-Path` location. When then scriptblock in invoked, the `$FileEvent` base Name/FullPath properties will be the Name/FullPath of the existing file.

```powershell
Add-PodeFileWatcher -EventName Existed -Path 'C:/websites' -ScriptBlock {
    # the Type will be set to "Existed"
    $FileEvent.Type | Out-Default

    # file name and path
    $FileEvent.Name | Out-Default
    $FileEvent.FullPath | Out-Default
}
```

#### Renamed

A File Watcher that triggers on the Renamed `-EventName` will call the defined `-ScriptBlock` whenever a file is renamed. When then scriptblock in invoked, the `$FileEvent` `Old` property will be initialised, and will contain the original Name/FullPath of the file before the rename. The base Name/FullPath properties will be the new Name/FullPath of the renamed file.

```powershell
Add-PodeFileWatcher -EventName Renamed -Path 'C:/websites' -ScriptBlock {
    # the Type will be set to "Renamed"
    $FileEvent.Type | Out-Default

    # new file name and path
    $FileEvent.Name | Out-Default
    $FileEvent.FullPath | Out-Default

    # original file name and path
    $FileEvent.Old.Name | Out-Default
    $FileEvent.Old.FullPath | Out-Default
}
```

### Parameters

The `-Path` parameter also supports URL parameter style syntax similar to Routes. For example, say you want to monitor every file for each website found at `C:/websites`, and each site is also its on directory at this path (ie: `C:/websites/example.com`). If you have multiple sites in this directory, you can use `C:/websites/:site` to watch every file in those subdirectories, but also be able to reference the website that had the file change via `$FileEvent.Parameters['site']`:

```powershell
Add-PodeFileWatcher -Path 'C:/websites/:site' -ScriptBlock {
    "[$($FileEvent.Type)][$($FileEvent.Parameters['site'])]: $($FileEvent.FullPath)" | Out-Default
}
```

You can have multiple parameters in a path, and reference them all via `$FileEvent.Parameters`.

### Include / Exclude

By default every file is monitored (ie: `*.*` on `-Include`). However you can customise the monitored files by using the `-Include` and `-Exclude` parameters.

For example, to monitor only config file you might use:

```powershell
Add-PodeFileWatcher -Path 'C:/websites' -Include '*.config' -ScriptBlock {
    "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
}
```

Or to monitor every file except for log files you might use:

```powershell
Add-PodeFileWatcher -Path 'C:/websites' -Exclude '*.log' -ScriptBlock {
    "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
}
```

The `-Include` and `-Exclude` parameters allow for an array of values to be supplied; so you might want to monitor all config files, but then also one specific "web.sitemap" file as well:

```powershell
Add-PodeFileWatcher -Path 'C:/websites' -Include '*.config', 'web.sitemap' -ScriptBlock {
    "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
}
```

### Subdirectories

When you create a File Watcher is will automatically monitor every file in every subdirectory. However you can change this behaviour to only monitor files in the specified directory by supplying `-NoSubdirectories`:

```powershell
Add-PodeFileWatcher -Path 'C:/websites' -NoSubdirectories -ScriptBlock {
    "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
}
```

## Arguments

You can supply custom arguments to be passed to your File Watchers by using the `-ArgumentList` parameter. This parameter takes an array of objects, which will be splatted onto the File Watcher's scriptblock:

```powershell
Add-PodeFileWatcher -Path 'C:/websites' -ArgumentList 'Item1', 'Item2' -ScriptBlock {
    param($i1, $i2)

    # $i1 will be 'Item1'
}
```

## Script from File

You normally define a File Watcher's script using the `-ScriptBlock` parameter however, you can also reference a file with the required scriptblock using `-FilePath`. Using the `-FilePath` parameter will dot-source a scriptblock from the file, and set it as the File Watcher's script.

For example, to create a File Watcher from a file that will output the file events to the console:

* File.ps1
```powershell
{
    "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
}
```

* File Watcher
```powershell
Add-PodeFileWatcher -Path 'C:/websites' -FilePath './FileWatchers/File.ps1'
```

## Getting File Watchers

The [`Get-PodeFileWatcher`](../../Functions/FileWatchers/Get-PodeFileWatcher) helper function will allow you to retrieve a list of File Watchers configured within Pode. You can use it to retrieve all of the File Watchers, or supply filters to retrieve specific ones.

To retrieve all of the File Watchers, you can call the function will no parameters. To filter, here are some examples:

```powershell
# one File Watchers by name
Get-PodeFileWatcher -Name Name1

# multiple File Watchers by name
Get-PodeFileWatcher -Name Name1, Name2
```

## File Watcher Object

!!! warning
    Be careful if you choose to edit these objects, as they will affect the server.

The following is the structure of the File Watcher object internally, as well as the object that is returned from [`Get-PodeFileWatcher`](../../Functions/FileWatchers/Get-PodeFileWatcher):

| Name | Type | Description |
| ---- | ---- | ----------- |
| Name | string | The name of the File Watcher |
| Events | string[] | The events that the File Watcher will trigger on |
| Path | string | The given main path the File Watcher is monitoring |
| Placeholders | hashtable | Specifies whether the given path contained parameters, and the regex path to retrieve them |
| Script | scriptblock | The scriptblock of the File Watcher |
| Arguments | object[] | The arguments supplied from ArgumentList |
| NotifyFilters | NotifyFilter[] | The attributes that will be used to trigger the defined events |
| IncludeSubdirectories | bool | Whether the File Watcher will monitor files in subdirectories or not |
| InternalBufferSize | int | The size of the internal buffer cache that stored triggered events |
| Exclude | string[] | The list of file types that should be excluded from triggering events |
| Include | string[] | The list of file types that should be included when triggering events |
| Paths | string[] | The list of all paths that will be monitored. For example, when the original path was a wildcard this will contain all resolved directory paths that the wildcard references |
