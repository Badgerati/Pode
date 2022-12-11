# Cron Expressions

Schedules and [`Auto Server Restarting`](../../Restarting/Types/AutoRestarting) in Pode use cron expressions to define when they trigger. This page is a brief overview of the expressions supported by Pode.

## Basic

Pode supports all basic features of cron expressions in the following format:

```plain
<min> <hour> <day-of-month> <month> <day-of-week>
```

For example, if you wanted to run a schedule that triggers every midnight on a Tuesday, the following would work:

```plain
0 0 * * TUE
```

Whereas if you wanted a schedule to trigger on the 15th of each month, at 1am:

```plain
0 1 15 * *
```

## Predefined

The following table outlines some of the predefined cron expressions supported by Pode; you can use these in place of normal cron expressions:

| Predefined | Expression |
| ---------- | ---------- |
| @minutely | `* * * * *` |
| @hourly | `0 * * * *` |
| @daily | `0 0 * * *` |
| @weekly | `0 0 * * 0` |
| @monthly | `0 0 1 * *` |
| @quarterly | `0 0 1 1,4,7,10 *` |
| @yearly | `0 0 1 1 *` |
| @annually | `0 0 1 1 *` |
| @twice-hourly | `0,30 * * * *` |
| @twice-daily | `0 0,12 * * *` |
| @twice-weekly | `0 0 * * 0,4` |
| @twice-monthly | `0 0 1,15 * *` |
| @twice-yearly | `0 0 1 1,6 *` |
| @twice-annually | `0 0 1 1,6 *` |

## Advanced

Pode does have some support for advanced cron features, including its own placeholder: `R`.

* `R`: using this on an atom will use a random value between that atom's constraints, and when the expression is triggered the atom is re-randomised - you can force an initial trigger value using `/R`. For example: `30/R * * * *` will trigger on 30mins, then a random minute afterwards; whereas using `R * * * *` will always trigger on a random minute between 0-59.

## Helper

Pode has an inbuilt helper function, [`New-PodeCron`](../../../Functions/Utilities/New-PodeCron), which can be used to generate cron expressions more easily. These cron expressions can then be used in [Schedules](../../Schedules) and other Pode functions that use cron expressions.

The main way to use [`New-PodeCron`](../../../Functions/Utilities/New-PodeCron) is to start with the `-Every` parameter, such as `-Every Hour` or `-Every Day`. From this, you can customise the expression to run at specific times/days, or apply a recurring `-Interval`:

```powershell
# Everyday, at 00:00
New-PodeCron -Every Day

# Every Tuesday and Friday, at 01:00
New-PodeCron -Every Day -Day Tuesday, Friday -Hour 1

# Every 15th of the month at 00:00
New-PodeCron -Every Month -Date 15

# Every other day, starting from the 2nd of each month, at 00:00
New-PodeCron -Every Date -Interval 2 -Date 2

# Every 1st June, at 00:00
New-PodeCron -Every Year -Month June

# Every hour, starting at 01:00
New-PodeCron -Every Hour -Hour 1 -Interval 1

# Every 15 minutes, between 01:00 and 05:00
New-PodeCron -Every Minute -Hour 1, 2, 3, 4, 5 -Interval 15

# Every hour of every Monday (ie: 00:00, 01:00, 02:00, etc.)
New-PodeCron -Every Hour -Day Monday

# Every 1st January, April, July, and October, at 00:00
New-PodeCron -Every Quarter

# Everyday at 05:15
New-PodeCron -Every Day -Hour 5 -Minute 15
```

You can also use [`New-PodeCron`](../../../Functions/Utilities/New-PodeCron) without using the `-Every` parameter. In this state, every part of the cron expression will be wildcarded by default - such as every minute, every hour, every day, etc. - unless you specify the parameter explicitly:

```powershell
# Every 10 minutes on Tuesdays
New-PodeCron -Day Tuesday -Minute 0, 10, 20, 30, 40, 50

# Every minute on Tuesdays
New-PodeCron -Day Tuesday
```
