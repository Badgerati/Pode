# Objects

This page describes the various .NET objects that will be supplied to Log Type and Method scriptblocks.

## Log Event

This is typically supplied to custom Log Type scriptblocks. It will be an `IPodeLogEvent` object with the following properties.

| Name      | Type           | Description                                         |
| --------- | -------------- | --------------------------------------------------- |
| Data      | `object`       | The raw log data from, for example, `Write-PodeLog` |
| Name      | `string`       | The name of the Log Type this event is for          |
| Level     | `PodeLogLevel` | The log level of this event                         |
| Metadata  | `hashtable`    | Any optionally supplied metadata                    |
| Timestamp | `datetime`     | The timestamp of this event                         |

## Log Item

This is typically supplied, as a list, to custom Log Method scriptblocks. It will be an `IPodeLogItem` object with the following properties.

| Name       | Type            | Description                                             |
| ---------- | --------------- | ------------------------------------------------------- |
| Data       | `object`        | The transformed log data returned by the Log Type       |
| Event      | `IPodeLogEvent` | The original Log Event for this Log Item                |
| ToString() | `method`        | A utility method return the Log Item's data as a string |

!!! tip
    `Data` here will be the transformed/serialised data from the Log Type. However, if you need access to the original raw data you'll find this under `Event.Data` - along with original Log Level and Timestamp.
