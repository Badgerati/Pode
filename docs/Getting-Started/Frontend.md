# Frontend

You can host web-pages using Pode, and to help you can also use package managers like `yarn` to install frontend libraries - like bootstrap.

## Using Yarn

The following will install Yarn onto your machine:

```powershell
choco install yarn -y
yarn init
```

Once installed, you can use Yarn to download frontend libraries. The libraries will be added to a `package.json` file - which if you're using the Pode CLI, you'll already have in place.

To install frontend libraries, you could use the following:

```powershell
yarn add bootstrap
yarn add lodash
```

## Pode Install

Once you've added some libraries you can use `pode install` to trigger `yarn`. This will tell `yarn` to install the packages to a `pode_modules` directory.

!!! info
    Other useful packages could include `gulp`, `jquery`, `moment`, etc.