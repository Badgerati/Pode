# Perf Tests

These tests run using a tool called [k6](https://k6.readme.io/docs/welcome), and scripts are written in ES6 JavaScript to define individual User Scenarios. You can tell `k6` to run using a number of Virtual Users over a defined Duration, or you can specify stages to ramp up/down the number of Virtual Users over a period of time.

## Installing

To install `k6` and run the tests locally, you can run the following command:

* Windows

```powershell
choco install k6 -y
```

* Linux

```bash
sudo curl -OL https://github.com/loadimpact/k6/releases/download/v0.20.0/k6-v0.20.0-linux64.tar.gz
sudo tar -xzf k6-v0.20.0-linux64.tar.gz
sudo cp k6-v0.20.0-linux64/k6 /usr/local/bin
```

After this, all `k6` commands are identical on Windows and Linux.

## Running

You can run `k6` against your local environment by using the following command (powershell/batch or bash):

```bash
k6 run -u 10 -d 10s ./basic/root.js
```

This will run k6 with 10 virtual users (`-u 10`) over 10 seconds (`-d 10s`).