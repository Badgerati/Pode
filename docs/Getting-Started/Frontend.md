# Frontend

You can host web-pages using Pode, as well as also using package managers like `yarn` to install frontend libraries - like bootstrap, jQuery, etc.

## Using Pode.Web

Don't know HTML, CSS, or JavaScript? No problem! [Pode.Web](https://github.com/Badgerati/Pode.Web) is currently a work in progress, and lets you build web pages using purely PowerShell!

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

You don't have to use Yarn, you could also use NPM or anything other package manager of your choice.

## Pode Install

Once you've added some libraries you can use `pode install` to trigger `yarn`. This will tell `yarn` to install the packages to a `pode_modules` directory. If you're using another package manager, you'll need to update the `install` property in the `package.json` file accordingly.

!!! info
    Other useful packages could include `gulp`, `jquery`, `moment`, etc.

Once these packages have been installed to `pode_modules`, this folder will contain other folders for the install libraries. In most cases, these library folders will contain a `dist` folder with files like `*.min.css` or `*.min.js`. You can then move these files into a `/public` folder at the root of your Pode server.

For example, if you install bootstrap then your `pode_modules` will look something like:

```plain
/pode_modules
    /bootstrap
        /dist
            bootstrap.min.css
            bootstrap.min.js
```

You then take those min files, and move them into `/public`:

```plain
/public
    bootstrap.min.css
    bootstrap.min.js
```

You can then reference these files in your HTML pages as:

```html
<link rel="stylesheet" type="text/css" href="/bootstrap.min.css">
<script src="/bootstrap.min.js"></script>
```

Instead of doing this manually, you could use tools like [`InvokeBuild`](https://github.com/nightroman/Invoke-Build) or [`psake`](https://github.com/psake/psake) to automate moving the files.
