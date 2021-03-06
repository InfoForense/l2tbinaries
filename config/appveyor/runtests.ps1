# Script to run tests on AppVeyor.

$ExitSuccess = 0
$ExitFailure = 1

Try
{
	If ($env:APPVEYOR_REPO_BRANCH -eq "master")
	{
		$Tags = Invoke-Expression -Command "git ls-remote --tags https://github.com/log2timeline/plaso.git"
		$Tags = $Tags | Sort-Object { [string]($_ -Split '\s+')[-1] } -Descending

		$LatestTag = (($Tags -Split '\n')[0] -Split 'refs/tags/')[1]

		$Output = Invoke-Expression -Command "git clone -b ${LatestTag} https://github.com/log2timeline/plaso.git 2>&1"
	}
	Else
	{
		$Output = Invoke-Expression -Command "git clone https://github.com/log2timeline/plaso.git 2>&1"
	}
	If (${LastExitCode} -ne ${ExitSuccess}) {Throw}

	# Out-String is used below to make sure new lines are preserved in the output.
	Write-Host (${Output} | Out-String)
}
Catch
{
	Write-Host (${Output} | Out-String) -foreground Red

        Exit ${ExitFailure}
}

Push-Location "plaso"

Try
{
	If ($env:TARGET -eq "gitsource")
	{
		$Output = Invoke-Expression -Command "& '${env:PYTHON}\python.exe' run_tests.py 2>&1"
		If (${LastExitCode} -ne ${ExitSuccess}) {Throw}
		Write-Host (${Output} | Out-String)
	}
	ElseIf ($env:TARGET -eq "l2tbinaries")
	{
		$Output = Invoke-Expression -Command "& '${env:PYTHON}\python.exe' ${env:PYTHON}\Scripts\log2timeline.py --status_view linear test.plaso test_data 2>&1"
		If (${LastExitCode} -ne ${ExitSuccess}) {Throw}
		Write-Host (${Output} | Out-String)

		$Output = Invoke-Expression -Command "& '${env:PYTHON}\python.exe' ${env:PYTHON}\Scripts\psort.py --status_view linear -w timeline.log test.plaso 2>&1"
		If (${LastExitCode} -ne ${ExitSuccess}) {Throw}
		Write-Host (${Output} | Out-String)
	}
}
Catch
{
	Write-Host (${Output} | Out-String) -foreground Red

	Exit ${ExitFailure}
}
Finally
{
	Pop-Location
}

