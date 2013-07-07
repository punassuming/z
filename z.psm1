<# 

.SYNOPSIS 

   Tracks your most used directories, based on 'frecency'.

.DESCRIPTION 

    After  a  short  learning  phase, z will take you to the most 'frecent'
    directory that matches ALL of the regexes given on the command line.
	
.PARAMETER JumpPath

A regular expression of the directory name to jump to.

.PARAMETER Option

r - Match by rank only
t - Match by recent access only
l - List only

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
    
z foo -o t

#>

$cdHistory = "$HOME\.cdhistory"

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
	    try {
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
	    } catch {
			throw
	    }
	}

	process
	{
	    try {
	        $steppablePipeline.Process($_)
			
			WriteCdCommandHistory # Build up the DB.
			
	    } catch [System.Management.Automation.ActionPreferenceStopException] {
	        throw
	    }
	}

	end
	{
	    try {
	        $steppablePipeline.End()		
	    } catch {
	        throw
	    }
	}
}

function z {
	param(
	[Parameter(Mandatory=$true, Position=0)]
	[string]
	${JumpPath},

	[ValidateSet("t", "f", "r", "l")]
	[Alias('o')]
	[string]
	$Option = 'f')

	if ((Test-Path $cdHistory)) {

		$history = [System.IO.File]::ReadAllLines($cdHistory)

		$list = @()

		$yer = $history | GetDirectoryEntry |
			? { [System.Text.RegularExpressions.Regex]::Match($_.Path.Name, $JumpPath, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Success } | FilterBasedOnArgs -Option $Option |
			% {
				$list += $_
			}
		
		if ($Option -eq 'l') {
			$list | % { New-Object PSObject -Property  @{Rank = $_.Rank; Path = $_.Path.FullName; LastAccessed = [DateTime]$_.Time } } | Format-Table -AutoSize
		} else {
			if ($list.Length -gt 1) {
							
				$list | Sort-Object -Descending { $_.Score } | select -First 1 | % { Set-Location $_.Path.FullName }

			} elseif ($list.Length -eq 0) {
				Write-Host "$JumpPath Not found"
			} else {
				Set-Location $list[0].Path
			}
		}
	}
}

function GetFrecency($rank, $time) {

	# Last access date/time
	$dx = (Get-Date).Subtract((New-Object System.DateTime -ArgumentList $time)).TotalSeconds

	if( $dx -lt 3600 ) { return $rank*4 }
    
	if( $dx -lt 86400 ) { return $rank*2 }
    
	if( $dx -lt 604800 ) { return $rank/2 }
	
    return $rank/4
}
			
function WriteCdCommandHistory() {

	$currentDirectory = Get-Location | select -ExpandProperty path

	$history = ''
	
	if ((Test-Path $cdHistory)) {
		$history = [System.IO.File]::ReadAllLines($cdHistory);
		Remove-Item $cdHistory
	}
	
	$foundDirectory = false
	$runningTotal = 0
	
	foreach ($line in $history) {
				
		if ($line -ne '') {
			$lineObj = GetDirectoryEntry $line
			if ($lineObj.Path.FullName -eq $currentDirectory) {	
				$lineObj.Rank++
				$foundDirectory = $true
				WriteHistoryEntry $cdHistory $lineObj.Rank $currentDirectory
			} else {
				[System.IO.File]::AppendAllText($cdHistory, $line + [Environment]::NewLine)
			}
			$runningTotal += $lineObj.Rank
		}
	}
	
	if (-not $foundDirectory) {
		WriteHistoryEntry $cdHistory 1 $currentDirectory
		$runningTotal += 1
	}
	
	if ($runningTotal -gt 6000) {
		
		$lines = [System.IO.File]::ReadAllLines($cdHistory)
		Remove-Item $cdHistory
		 $lines | % {
		 	$lineObj = GetDirectoryEntry $_
			$lineObj.Rank = $lineObj.Rank * 0.99
			
			if ($lineObj.Rank -ge 1 -or $lineObj.Age -lt 86400) {
				WriteHistoryEntry $cdHistory $lineObj.Rank $lineObj.Path
			}
		}
	}
}

function FormatRank($rank) {
	return $rank.ToString("000#.00");
}

function WriteHistoryEntry($cdHistory, $rank, $directory) {
	$newline = [Environment]::NewLine
	[System.IO.File]::AppendAllText($cdHistory, (FormatRank $rank) + (Get-Date).Ticks + $directory + $newline)	
}

function GetDirectoryEntry {
	Param(
		[Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
    	[String]$line
	)
	
	Process {
		$matches = [System.Text.RegularExpressions.Regex]::Match($line, '(\d+\.\d{2})(\d+)(.*)');

		$dir = (New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $matches.Groups[3].Value);
		
		$obj = @{
		  Rank=[decimal]::Parse($matches.Groups[1].Value);
		  Time=[long]::Parse($matches.Groups[2].Value);
		  Path=$dir;
		};
		
		return $obj;
	}
}

function FilterBasedOnArgs {
	Param(
		[Parameter(ValueFromPipeline=$true)]
    	[Hashtable]$historyEntry,
		
		[string]
		$Option = 'f'
	)
	
	Process {
				
		if ($Option -eq 'f') {
			$_.Add('Score', (GetFrecency $_.Rank $_.Time));
		} elseif ($Option -eq 't') {
			$_.Add('Score', $_.Time);
		} elseif ($Option -eq 'r') {
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