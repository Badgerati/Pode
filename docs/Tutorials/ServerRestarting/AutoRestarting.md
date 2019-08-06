# Auto-Restarting

You can schedule automatic server restarts by using the `server.restart` section within your `server.psd1` configuration file. You can schedule server restarts in 3 ways:

1. **Periodic**: A single value that defines after how many minutes the server should restart.
2. **Times**: An array of times that define at which times each day the server should restart.
3. **Cron Expressions**: An array of [`cron expression`](../../Misc/CronExpressions) that define when the server should restart.

The section in your `server.psd1` file could look as follows (you can define 1 or all):

```powershell
@{
    Server = @{
        Restart = @{
            Period = 180
            Times = @("09:00", "21:00")
            Crons = @("@hourly", "30 14 * * TUE")
        }
    }
}
```

## Periodic

Periodic server restarts are defined using a single value, which is the number of minutes to wait before triggering a server restart. For example, if you wanted to restart your server every 6hrs, then you could add the following to your `server.psd1` file:

```powershell
@{
    Server = @{
        Restart = @{
            Period = 360
        }
    }
}
```

!!! note
    The period starts from the moment the server is started.

## Times

Server restarts can be fined by the time of day, this is an array of times each day to restart your server. For example, if you wanted to restart your server at 09:45 and 21:15 every day, then you could add the following to your `server.psd1` file:

```powershell
@{
    Server = @{
        Restart = @{
            Times = @("09:45", "21:15")
        }
    }
}
```

## Cron Expressions

To further advance timed and periodic server restarts, you can also define when a restart should occur by using an array of [`cron expressions`](../../Misc/CronExpressions). For example, should you want to restart your server on every Tuesday and Friday at 12:00, then you could add the following to your `server.psd1` file:

```powershell
@{
    Server = @{
        Restart = @{
            Crons = @("0 12 * * TUE,FRI")
        }
    }
}
```
