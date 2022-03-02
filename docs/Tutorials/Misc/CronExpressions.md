# Cron Expressions

Schedules and [`Auto Server Restarting`](../../Restarting/AutoRestarting) in Pode use cron expressions to define when they trigger. This page is a brief overview of the expressions supported by Pode.

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
| @quarterly | `0 0 1 1,4,8,7,10 *` |
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
