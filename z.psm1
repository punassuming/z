$cdHistory = "$HOME\.cdhistory"

<# 

.SYNOPSIS 

   Tracks your most used directories, based on 'frecency'.

.DESCRIPTION 

    After  a  short  learning  phase, z will take you to the most 'frecent'
    directory that matches the regex given on the command line.
	
.PARAMETER JumpPath

A regular expression of the directory name to jump to.

.PARAMETER Option

Frecency - Match by frecency (default)
Rank - Match by rank only
Time - Match by recent access only
List - List only
CurrentDirectory - Restrict matches to subdirectories of the current directory

.PARAMETER $ProviderDrives

A comma separated string of drives to match on. If none is specified, it will use a drive list from the currently selected provider.

For example, the following command will run the regular expression 'foo' against all folder names where the drive letters in your history match HKLM:\ C:\ or D:\

z foo -p HKLM,C,D

.NOTES

Current PowerShell implementation is very crude and does not yet support all of the options of the original z bash script.
Although tracking of frequently used directories is obtained through the continued use of the "cd" command, the Windows registry is also scanned for frequently accessed paths.
	
.LINK 

   https://github.com/vincpa/z
   
.EXAMPLE

CD to the most frecent directory matching 'foo'

z foo

.EXAMPLE

CD to the most recently accessed directory matching 'foo'

z foo -o Time

#>
function z {
	param(
	[Parameter(Mandatory=$true, Position=0)]
	[string]
	${JumpPath},

	[ValidateSet("Time", "Frecency", "Rank", "List", "CurrentDirectory")]
	[Alias('o')]
	[string]
	$Option = 'Frecency',
	
	[Alias('p')]
	[string[]]
	$ProviderDrives = $null)

	if ((Test-Path $cdHistory)) {
		
		$mruList = Get-MostRecentDirectoryEntries
		
		$history = [System.IO.File]::ReadAllLines($cdHistory) + $mruList

		$providerRegex = Get-CurrentSessionProviderDrives $ProviderDrives
		
		$list = @()

		$history.Split([Environment]::NewLine) | ? { (-not [String]::IsNullOrWhiteSpace($_)) } | ConvertTo-DirectoryEntry |
			? { Get-DirectoryEntryMatchPredicate -path $_.Path -jumpPath $JumpPath -ProviderRegex $providerRegex } | Get-ArgsFilter -Option $Option |
			% {
				$list += $_
			}
		
		if ($Option -eq 'List') {
			$list | % { New-Object PSObject -Property  @{Rank = $_.Rank; Path = $_.Path.FullName; LastAccessed = [DateTime]$_.Time } } | Format-Table -AutoSize
		} else {
			if ($list.Length -gt 1) {
							
				$list | Sort-Object -Descending { $_.Score } | select -First 1 | % { Set-Location $_.Path.FullName }

			} elseif ($list.Length -eq 0) {
				Write-Host "$JumpPath Not found"
			} else {
				Set-Location $list[0].Path.FullName
			}
		}
	}
}

# A wrapper function around the existing Set-Location Cmdlet.
function cdX
{
	[CmdletBinding(DefaultParameterSetName='Path', SupportsTransactions=$true, HelpUri='http://go.microsoft.com/fwlink/?LinkID=113397')]
	param(
	    [Parameter(ParameterSetName='Path', Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
	    [string]
	    ${Path},

	    [Parameter(ParameterSetName='LiteralPath', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
	    [Alias('PSPath')]
	    [string]
	    ${LiteralPath},

	    [switch]
	    ${PassThru},

	    [Parameter(ParameterSetName='Stack', ValueFromPipelineByPropertyName=$true)]
	    [string]
	    ${StackName})

	begin
	{
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }
		
		$PSBoundParameters['ErrorAction'] = 'Stop'
		
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Set-Location', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd @PSBoundParameters }
				
        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)					
	}

	process
	{
        $steppablePipeline.Process($_)
		
		Save-CdCommandHistory # Build up the DB.
	}

	end
	{
	    $steppablePipeline.End()
	}
}

function Get-DirectoryEntryMatchPredicate {
	Param(
		[Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
    	$Path,
		
		[Parameter(
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
		[string] $JumpPath,
		
		[string] $ProviderRegex
	)
	
	if ($Path -ne $null) {
		
		$null = .{
			
			$providerMatches = [System.Text.RegularExpressions.Regex]::Match($Path.FullName, $ProviderRegex).Success
			
			Write-Host 'Regex: ' $providerRegex ' Match: ' $providerMatches.ToString().PadRight(5, ' ') 'Path: ' $Path.FullName
		}
		
		if ($providerMatches) {
			[System.Text.RegularExpressions.Regex]::Match($Path.Name, $JumpPath).Success
		}
	}
}

function Get-CurrentSessionProviderDrives([string[]] $ProviderDrives) {
	
	if ($ProviderDrives -ne $null -and $ProviderDrives.Length -gt 0) {
		Get-ProviderDrivesRegex $ProviderDrives
	} else {
			
		# The FileSystemProvider supports \\ and X:\ paths.
		# An ideal solution would be to ask the provider if a path is supported.
		# Supports drives such as C:\ and also UNC \\
		if ((Get-Location).Provider.ImplementingType.Name -eq 'FileSystemProvider') {
			'(?i)^(((' + [String]::Concat( ((Get-Location).Provider.Drives.Name | % { $_ + '|' }) ).TrimEnd('|') + '):\\)|(\\{2})).*?'
		} else {
			Get-ProviderDrivesRegex (Get-Location).Provider.Drives
		}
	}
}

function Get-ProviderDrivesRegex([string[]] $ProviderDrives) {
	'(?i)^((' + [String]::Concat( ($ProviderDrives | % { $_ + '|' }) ).TrimEnd('|') + '):\\).*?'
}

function Get-Frecency($rank, $time) {

	# Last access date/time
	$dx = (Get-Date).Subtract((New-Object System.DateTime -ArgumentList $time)).TotalSeconds

	if( $dx -lt 3600 ) { return $rank*4 }
    
	if( $dx -lt 86400 ) { return $rank*2 }
    
	if( $dx -lt 604800 ) { return $rank/2 }
	
    return $rank/4
}
			
function Save-CdCommandHistory() {

	$currentDirectory = Get-FormattedLocation

	$history = ''
	
	try {

		# Copy contents of file in to memory.
		if ((Test-Path $cdHistory)) {
			$history = [System.IO.File]::ReadAllLines($cdHistory);
			Remove-Item $cdHistory
		}
		
		$foundDirectory = $false
		$runningTotal = 0
		
		foreach ($line in $history) {
					
			if ($line -ne '') {
				$lineObj = ConvertTo-DirectoryEntry $line
				if ($lineObj.Path.FullName -eq $currentDirectory) {	
					$lineObj.Rank++
					$foundDirectory = $true
					Save-HistoryEntry $cdHistory $lineObj.Rank $currentDirectory
				} else {
					[System.IO.File]::AppendAllText($cdHistory, $line + [Environment]::NewLine)
				}
				$runningTotal += $lineObj.Rank
			}
		}
		
		if (-not $foundDirectory) {
			Save-HistoryEntry $cdHistory 1 $currentDirectory
			$runningTotal += 1
		}
		
		if ($runningTotal -gt 6000) {
			
			$lines = [System.IO.File]::ReadAllLines($cdHistory)
			Remove-Item $cdHistory
			 $lines | % {
			 	$lineObj = ConvertTo-DirectoryEntry $_
				$lineObj.Rank = $lineObj.Rank * 0.99
				
				if ($lineObj.Rank -ge 1 -or $lineObj.Age -lt 86400) {
					Save-HistoryEntry $cdHistory $lineObj.Rank $lineObj.Path.FullName
				}
			}
		}
	} catch {
		$history | Out-File $cdHistory # Restore file should an error occur.
		Write-Host $_.Exception.ToString() -ForegroundColor Red
	}
}

function Get-FormattedLocation() {
	if ((Get-Location).Provider.ImplementingType.Name -eq 'RegistryProvider') {
		Get-Location | select -ExpandProperty Path # The registry provider does return a path which z understands. In other words, I'm too lazy.
	} else {
		Get-Location | select -ExpandProperty ProviderPath
	}
}

function Format-Rant($rank) {
	return $rank.ToString("000#.00");
}

function Save-HistoryEntry($cdHistory, $rank, $directory) {
	$entry = ConvertTo-HistoryEntry $rank $directory
	[System.IO.File]::AppendAllText($cdHistory, $entry)
}

function ConvertTo-HistoryEntry($rank, $directory) {
	$newline = [Environment]::NewLine
	(Format-Rant $rank) + (Get-Date).Ticks + $directory + $newline
}

function ConvertTo-DirectoryEntry {
	Param(
		[Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
    	[String]$line
	)
	
	Process {

		$null = .{
		
			$matches = [System.Text.RegularExpressions.Regex]::Match($line, '(\d+\.\d{2})(\d+)(.*)');

			$pathValue = $matches.Groups[3].Value.Trim()
			
			try {	
				[System.IO.Path]::GetFileName($pathValue);
			} catch [System.ArgumentException] { }
		}

		@{
		  Rank=[double]::Parse($matches.Groups[1].Value);
		  Time=[long]::Parse($matches.Groups[2].Value);
		  Path=@{ Name = $pathValue; FullName = $matches.Groups[3].Value; }
		}
	}
}

function Get-MostRecentDirectoryEntries {

	$mruEntries = (Get-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths | % { $item = $_; $_.GetValueNames() | % { $item.GetValue($_) } })
		
	$mruEntries | % { ConvertTo-HistoryEntry 1 $_ }
}

function Get-ArgsFilter {
	Param(
		[Parameter(ValueFromPipeline=$true)]
    	[Hashtable]$historyEntry,
		
		[string]
		$Option = 'Frecency'
	)
	
	Process {
				
		if ($Option -eq 'Frecency') {
			$_.Add('Score', (Get-Frecency $_.Rank $_.Time));
		} elseif ($Option -eq 'Time') {
			$_.Add('Score', $_.Time);
		} elseif ($Option -eq 'Rank') {
			$_.Add('Score', $_.Rank);
		}
		
		return $_;
	}
}

<#

.ForwardHelpTargetName Set-Location
.ForwardHelpCategory Cmdlet

#>

#Override the existing CD command with the wrapper in order to log 'cd' commands.
Set-Alias -Name cd -Value cdX -Force -Option AllScope -Scope Global

Export-ModuleMember -Function z, cdX -Alias cd