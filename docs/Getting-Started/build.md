
# Build Pode locally

To build and use the code checked out on your machine, follow these steps :

## Windows

1. Install InvokeBuild Module

    ### Using Powershell Gallery

    ```powershell
    Install-Module InvokeBuild -Scope CurrentUser
    ```

    ### Using Chocolatey

    ```powershell
    choco install invoke-build
    ```

2. Test

    To run the unit tests, run the following command from the root of the repository (this will build Pode and, if needed, auto-install Pester/.NET):

    ```powershell
    Invoke-Build Test
    ```

3. Build

    To just build Pode, before running any examples, run the following:

    ```powershell
    Invoke-Build Build
    ```

4. Packaging

    To create a Pode package. Please note that docker has to be present to create the containers.

    ```powershell
    Invoke-Build Pack
    ```

5. Install locally

    To install Pode from the repository, run the following:

    ```powershell
    Invoke-Build Install-Module
    ```

    To uninstall, use :
    ```powershell
    Invoke-Build Remove-Module
    ```


6. CleanUp

    To clean up after a build or a pack, run the following:

    ```powershell
    Invoke-Build clean
    ```

## Linux

1. Register the Microsoft Repository

    #### Centos
    ```shell
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo curl -o /etc/yum.repos.d/microsoft.repo https://packages.microsoft.com/config/centos/8/prod.repo
    ```

    #### ReadHat
    ```shell
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo curl -o /etc/yum.repos.d/microsoft.repo https://packages.microsoft.com/config/rhel/9/prod.repo
    ```

    #### Debian / Ubuntu
    ```shell
    sudo apt-get update
    sudo apt-get install -y wget apt-transport-https software-properties-common
    wget https://packages.microsoft.com/config/debian/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo apt-get update;
    ```


3. Install InvokeBuild Module

    ```powershell
    Install-Module InvokeBuild -Scope CurrentUser
    ```


4. Test

    To run the unit tests, run the following command from the root of the repository (this will build Pode and, if needed, auto-install Pester/.NET):

    ```powershell
    Invoke-Build Test
    ```

5. Build

    To just build Pode, before running any examples, run the following:

    ```powershell
    Invoke-Build Build
    ```

6. Packaging

    To create a Pode package. Please note that docker has to be present to create the containers.

    ```powershell
    Invoke-Build Pack
    ```

7. Install locally

    To install Pode from the repository, run the following:

    ```powershell
    Invoke-Build Install-Module
    ```

    To uninstall, use :

    ```powershell
    Invoke-Build Remove-Module
    ```


## MacOS

An easy way to install the required componentS is to use [brew](https://brew.sh/)

1. Install dotNet

    ```shell
    brew install dotnet
    ```

2. Install InvokeBuild Module

    ```powershell
    Install-Module InvokeBuild -Scope CurrentUser
    ```

3. Test

    To run the unit tests, run the following command from the root of the repository (this will build Pode and, if needed, auto-install Pester/.NET):

    ```powershell
    Invoke-Build Test
    ```

4. Build

    To just build Pode, before running any examples, run the following:

    ```powershell
    Invoke-Build Build
    ```

5. Packaging

    To create a Pode package. Please note that docker has to be present to create the containers.

    ```powershell
    Invoke-Build Pack
    ```

6. Install locally

    To install Pode from the repository, run the following:

    ```powershell
    Invoke-Build Install-Module
    ```

    To uninstall, use :

    ```powershell
    Invoke-Build Remove-Module
    ```

