
# GitHub Codespace and Pode

GitHub Codespaces provides a cloud-based development environment directly integrated with GitHub. This allows you to set up your development environment with pre-configured settings, tools, and extensions. In this guide, we will walk you through using GitHub Codespace to work with Pode, a web framework for building web applications and APIs in PowerShell.

## Prerequisites

- A GitHub account
- A repository set up for your Pode project, including the `devcontainer.json` configuration file.

## Launching GitHub Codespace

1. **Open GitHub Codespace:**

   Go to your GitHub repository on the web. Click on the green `Code` button, and then select `Open with Codespaces`. If you don't have any Codespaces created, you can create a new one by clicking `New codespace`.

2. **Codespace Initialization:**

   Once the Codespace is created, it will use the existing `devcontainer.json` configuration to set up the environment. This includes installing the necessary VS Code extensions and PowerShell modules specified in the configuration.

3. **Verify the Setup:**

   - The terminal in the Codespace will default to PowerShell (`pwsh`).
   - Check that the required PowerShell modules are installed by running:

     ```powershell
     Get-Module -ListAvailable
     ```

     You should see `InvokeBuild` and `Pester` listed among the available modules.

## Running a Pode Application

1. **Use an Example Pode Project:**

   Pode comes with several examples in the `examples` folder. You can run one of these examples to verify that your setup is working. For instance, let's use the `HelloWorld` example.

2. **Open HelloWorld**

   Navigate to the `examples/HelloWorld` directory and open the `HelloWorld.ps1` file

3. **Run the sample**

   Run the Pode server by executing the `HelloWorld.ps1` script in the PowerShell terminal:

   ```powershell
   ./examples/HelloWorld/HelloWorld.ps1
   ```
   or using the `Run/Debug` on the UI

4. **Access the Pode Application:**

   Once the Pode server is running, you can access your Pode application by navigating to the forwarded port provided by GitHub Codespaces. This is usually indicated by a URL in the terminal or in the Codespaces interface.

For more information on using Pode and its features, refer to the [Pode documentation](https://badgerati.github.io/Pode/).
