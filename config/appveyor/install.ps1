# Script to set up tests on AppVeyor.

Function DownloadFile($Url, $Destination)
{
	$Client = New-Object Net.WebClient
	${Client}.DownloadFile(${Url}, ${Destination})
}

Function ExtractZip($Filename)
{
	# AppVeyor does not seem to support extraction using "native ZIP" so we use 7z instead.
	$SevenZip = "C:\Program Files\7-Zip\7z.exe"

	If (Test-Path ${SevenZip})
	{
		# PowerShell will raise NativeCommandError if 7z writes to stdout or stderr
		# therefore 2>&1 is added and the output is stored in a variable.
		# The leading & and single quotes are necessary to compensate for the spaces in the path.
		$Output = Invoke-Expression -Command "& '${SevenZip}' -y x ${Filename} 2>&1"
	}
	else
	{
		$Shell = New-Object -ComObject Shell.Application
		$Archive = ${Shell}.NameSpace(${Filename})
		$Directory = ${Shell}.Namespace("${pwd}")

		ForEach($FileEntry in ${Archive}.items())
		{
			${Directory}.CopyHere(${FileEntry})
		}
	}
}

If ($env:APPVEYOR_REPO_BRANCH -eq "master" )
{
	$Track = "stable"
}
Else
{
	$Track = $env:APPVEYOR_REPO_BRANCH
}
New-Item -ItemType "directory" -Name "dependencies"

$env:PYTHONPATH = "..\l2tdevtools"

$Output = Invoke-Expression -Command "& '${env:PYTHON}\python.exe' ..\l2tdevtools\tools\update.py --download-directory dependencies --machine-type ${env:MACHINE_TYPE} --msi-targetdir ${env:PYTHON} --track ${Track} 2>&1"

Write-Host ${Output}

