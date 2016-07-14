## z

z lets you quickly navigate the file system in PowerShell based on your `cd` command history. It's a port of [the z bash shell script.](README)

## Goals

Since 27 June 2013 I have poured many many hours building, tweaking and refining this script to work with PowerShell. It saves me a great deal of time navigating the file system, which is where I spent a lot of my time and has given me a great oportunity to learn PowerShell at a deeper level. There are no unit tests (yet), but I wrote the script to save me time and learn PowerShell. Enjoy!

The goal is quite simple, save time typing out the fully qualified path names of frequently accessed directories.

![ExampleUsage]

## Examples

Once installed, `cd` in to a few directories

`cd foo`

`cd HKLM:\software\Microsoft\Office`

`cd 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files'`

Based on the sample commands above, the results would be:

	z foo				cd to most frecent folder matching foo
	
	z temp				cd to most frecent folder matching `Temporary ASP.NET Files`

	z foo -o r			cd to highest ranked folder matching foo

	z foo -o f			cd to highest frecency folder matching foo
	
	z -l foo			list all dirs matching regex foo

	z office			cd to most frecent folder matching office in drive HKLM (The registry)
	
	z -x				remove the current directory from the datafile

Unless the -p parameter is specified, the regex you specify will be matched against a filtered drive listing from the current provider. If for example, you're on the C: then the following two commands could be simply replaced by `z foo` as they belong to the same provider and all drives will be searched. But you can be specific if you like.

	z foo -p c,d	cd to most frecent folder matching foo in drives C: and D:
	
	z foo -p \\ 	cd to most frecent folder matching foo for UNC paths

### Limitations

Below is a list of features which have not yet been ported from the original `z` bash script...yet.

* Specifying two separate regex's and matching on both, i.e. `z foo bar`
* Does not have the ability to restrict searches to sub-directories of the current directory

### Added sugar

* An in-memory history data file for increased performance. Useful for those who are heavy users of the command line

* Works with registry paths such as `HKLM\Software\....` and NetBIOS paths such as `\\server\share`. I have also tested this with [StudioShell](https://studioshell.codeplex.com/) which helps navigating Visual Studio that much faster.

* Executing pushd will record the current directory for use with `z`.

### Planned Features

[See the issue listing](https://github.com/vincpa/z/issues)

### PowerShell installation

#### The easy way using PsGet

If you have [PSGet](http://psget.net/) installed, run: `Install-Module z`

If you have do not have PSGet installed, see their page for instructions.

Once complete, you'll still need to run the command `Import-Module z` and place it in your startup profile.

### The easy way using PowerShellGet

For those with Windows 7 and above, you can issue a `Install-Module -Name z` command.

See the module listing in the [official PowerShell gallary](https://www.powershellgallery.com/packages/z/)

Once complete, run the command `Import-Module z`. For ease of use I recomend placing this command in your PowerShell startup profile.

#### The hard way

Download the `z.psm1` file and save it to your PowerShell module directory.The default location for this is `$env:USERPROFILE\Documents\WindowsPowerShell\Modules\z` (relative to your Documents folder). You can also extract it to another directory listed in your `$env:PSModulePath`. 

Assuming you want `z` to be avilable in every PowerShell session, open your profile script located at '$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' and add the following line.

`Import-Module z`

If the file `Microsoft.PowerShell_profile.ps1` does not exist, you can simply create it and it will be executed the next time a PowerShell session starts.

### Running z

Once the module is installed and has been imported in to your session you can start jumping around. Remember, you need to build up the DB of directories first so be sure to `cd` around your file system.

[ExampleUsage]: https://raw.githubusercontent.com/vincpa/z/master/example_usage.gif
