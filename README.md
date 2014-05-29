## z

z lets you quickly navigate the file system in PowerShell based on your `cd` command history. It's a port of [the z bash shell script.](README)

## Goals

Save time typing out frequently used paths.

## Examples

	z foo         cd to most frecent dir matching foo

	z foo -r      cd to highest ranked dir matching foo

	z foo -r      cd to most recently accessed dir matching foo

	z foo -l      list all dirs matching foo (by frecency)

### Limitations

Below is a list of features which have not yet been ported from the original `z` bash script...yet.

* Specifying two separate regex's and matching on both, i.e. `z foo bar`
* Does not have the ability to restrict searches to sub-directories of the current directory
* Listing matches only
* Removing historical entries

### Added sugar

I have added one feature which the original script did not do and that is look up recently used paths from Windows MRU listing.

It also works with registry paths such as `HKLM\Software\....` and NetBIOS paths such as `\\server\share`. I have also tested this with [StudioShell](https://studioshell.codeplex.com/) which helps navigating Visual Studio that much faster.

### Planned Features

* Support for pushd/popd

[See the issue listing](https://github.com/vincpa/z/issues)

### PowerShell installation

Download the `z.psm1` file and save it to your PowerShell module directory.The default location for this is `.\WindowsPowerShell\Modules` (relative to your Documents folder). You can also extract it to another directory listed in your `$env:PSModulePath`. 

Assuming you want `z` to be avilable in every PowerShell session, open your profile script located at '$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' and add the following line.

`Import-Module z`

If the file `Microsoft.PowerShell_profile.ps1` does not exist, you can simply create it and it will be executed the next time a PowerShell session starts.

### Running z

To run `z`, run the following command.

	Import-Module z

Once the module is installed, you can start jumping around. Remember, you need to build up the DB of directories first so be sure to `cd` around your file system.
