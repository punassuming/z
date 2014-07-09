## z

z lets you quickly navigate the file system in PowerShell based on your `cd` command history. It's a port of [the z bash shell script.](README)

## Goals

Save time typing out frequently used paths.

## Examples

Unless the -p parameter is specified, the regex you specify will be matched against a filtered drive listing from the current provider.

	z foo			cd to most frecent folder matching foo

	z foo -o r		cd to highest ranked folder matching foo

	z foo -o r		cd to most recently accessed folder matching foo

	z foo -o l		list all dirs matching folder foo (by frecency)
	
	z . -o l		list all history entries in the datafile

	z foo -p hklm	cd to most frecent folder matching foo in drive HKLM (The registry)
	
	z -x			remove the current directory from the datafile
	
If one was on the C: then the following two commands could be simply replaced by `z foo` as they belong to the same provider and all drives will be searched. But you can be specific if you like.

	z foo -p c,d	cd to most frecent folder matching foo in drives C: and D:
	
	z foo -p \\ 	cd to most frecent folder matching foo for UNC paths

### Limitations

Below is a list of features which have not yet been ported from the original `z` bash script...yet.

* Specifying two separate regex's and matching on both, i.e. `z foo bar`
* Does not have the ability to restrict searches to sub-directories of the current directory

### Added sugar

I have added one feature which the original script did not do and that is look up recently used paths from Windows MRU listing.

It also works with registry paths such as `HKLM\Software\....` and NetBIOS paths such as `\\server\share`. I have also tested this with [StudioShell](https://studioshell.codeplex.com/) which helps navigating Visual Studio that much faster.

### Planned Features

* Support for pushd/popd

[See the issue listing](https://github.com/vincpa/z/issues)

### PowerShell installation

#### The easy way

If you have [PSGet](http://psget.net/) installed, run: `Install-Module z`

If you have do not have PSGet installed:

`(new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | iex`<br/>
`Install-Module z`

Once complete, you'll still need to run the command `Import-Module z` and place it in your startup profile.

#### The manual way
Download the `z.psm1` file and save it to your PowerShell module directory.The default location for this is `.\WindowsPowerShell\Modules` (relative to your Documents folder). You can also extract it to another directory listed in your `$env:PSModulePath`. 

Assuming you want `z` to be avilable in every PowerShell session, open your profile script located at '$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' and add the following line.

`Import-Module z`

If the file `Microsoft.PowerShell_profile.ps1` does not exist, you can simply create it and it will be executed the next time a PowerShell session starts.

### Running z

To run `z`, run the following command.

	Import-Module z

Once the module is installed, you can start jumping around. Remember, you need to build up the DB of directories first so be sure to `cd` around your file system.
