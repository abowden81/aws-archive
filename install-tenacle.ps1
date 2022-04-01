Param (
	[string]$role,
	[string]$name,
	[string]$environmentName
)

#Change dll path accordingly
Add-Type -Path D:\\Octopus\\Tentacle\\Newtonsoft.Json.dll
Add-Type -Path D:\\Octopus\\Tentacle\\Octopus.Client.dll
Add-Type -Path D:\\Octopus\\Tentacle\\Octopus.Manager.Core.dll

$OctopusURL = 'https://octopus.ofx.private'
$OctopusAPIKey = 'API-0DTWS64XIQLYICORGGFQLEDX2W'

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusURL,$OctopusAPIKey
$repository = new-object Octopus.Client.OctopusRepository $endpoint

function GiveTeamEnvironmentPermission([string]$teamName, [string]$envName)
{
	try
	{
		#Getting environments to add
		$EnvironmentsToAdd = $repository.Environments.FindOne({ param ($a) $a.Name -eq $envName })
	
		if (!($EnvironmentsToAdd))
		{
			Write-Error 'Environment not found:' $envName
			return
		}
	
		#Getting target team	
		$team = $repository.Teams.FindOne({ param ($a) $a.Name -eq $teamName })
		if(!($team)){
			Write-Error 'Team not found:' $teamName
			return
		}
	
		#Adding environments to team if dont exist
	
		if (!$team.EnvironmentIds.Contains($EnvironmentsToAdd.id))
		{
			$team.EnvironmentIds.Add($EnvironmentsToAdd.id)
		
			#Save changes
			$repository.Teams.Modify($team)
		}	
	}
	catch { }
}

function AddToLifeCycle([string]$lifeCycleName, [string]$envName, [string]$phaseName)
{		
	try
	{
		#Getting environments to add
		$EnvironmentsToAdd = $repository.Environments.FindOne({ param ($a) $a.Name -eq $envName })
	
		if (!($EnvironmentsToAdd))
		{
			Write-Error 'Environment not found:' $envName
			return
		}
	
		#Getting lifecyle
		$lifecycle = $repository.Lifecycles.FindOne({ param ($a) $a.Name -eq $lifeCycleName })		
		if (!($lifecycle))
		{
			Write-Error 'Lifecycle not found:' $lifeCycleName
			return
		}
	
		#Get phase
		$phase = $lifecycle.Phases | ? { $_.name -eq $phaseName }
		if (!($phase))
		{
			Write-Error 'Phase not found:' $phaseName
			return
		}
	
	
		#Adding environments to phase if dont exist
		if (!$phase.OptionalDeploymentTargets.Contains($EnvironmentsToAdd.id))
		{
			$phase.OptionalDeploymentTargets.Add($EnvironmentsToAdd.id)
		
			#Save changes
			$repository.Lifecycles.Modify($lifecycle)
		}
	}
	catch { }
}


#1. Register/Replace environment 
$role.Split('*') | ForEach-Object { $roleString += ' --role ' + $_ }
$octopusName = $name + '.' + $environmentName + '.ofx.private'

cinst -y octopustools
octo create-environment --name $environmentName --server $OctopusURL --apiKey=$OctopusAPIKey --ignoreIfExists
Start-Process -FilePath msiexec -ArgumentList '/i D:\\Installers\\Octopus.Tentacle.msi /quiet INSTALLLOCATION=D:\\Octopus\\Tentacle' -wait
D:\\Octopus\\Tentacle\\Tentacle.exe create-instance --instance Tentacle --config D:\\Octopus\\Tentacle.config --console
D:\\Octopus\\Tentacle\\Tentacle.exe new-certificate --instance Tentacle --if-blank --console
D:\\Octopus\\Tentacle\\Tentacle.exe configure --instance Tentacle --reset-trust --console
D:\\Octopus\\Tentacle\\Tentacle.exe configure --instance Tentacle --home D:\\Octopus --app D:\\Octopus\\Applications --port 10933 --console
D:\\Octopus\\Tentacle\\Tentacle.exe configure --instance Tentacle --trust 622A0A6B1C902DD7DC454199A582A898FAB24AAB --console
netsh advfirewall firewall add rule name=OctopusTentacle dir=in action=allow protocol=TCP localport=10933
D:\\Octopus\\Tentacle\\Tentacle.exe service --instance Tentacle --install --start --console
$registerExp = 'D:\\Octopus\\Tentacle\\Tentacle.exe register-with --instance Tentacle --server $OctopusURL --apiKey=API-0DTWS64XIQLYICORGGFQLEDX2W' + $roleString + ' --environment $environmentName --comms-style TentaclePassive --publicHostname=$octopusName --name=$octopusName --console --force | Write-Host'
Invoke-Expression $registerExp

#2.Give new environment access to teams
if (($environmentName.Contains('.dev')) -and (!$environmentName.Contains('00.dev'))) {
	GiveTeamEnvironmentPermission 'Developers' $environmentName
	GiveTeamEnvironmentPermission 'Technical Lead' $environmentName
	AddToLifeCycle	'Development Lifecycle' $environmentName 'Developer Testing'
	AddToLifeCycle	'Non-cycle' $environmentName 'phases'	
}
elseif ($environmentName.Contains('.sit')) {
	GiveTeamEnvironmentPermission 'QA' $environmentName
	GiveTeamEnvironmentPermission 'Technical Lead' $environmentName
	AddToLifeCycle	'Development Lifecycle' $environmentName 'Integration Testing'
	AddToLifeCycle	'Non-cycle' $environmentName 'phases'
}
else
{
	GiveTeamEnvironmentPermission 'DevOps' $environmentName
	AddToLifeCycle	'Development Lifecycle' $environmentName 'Release'
	AddToLifeCycle	'Non-cycle' $environmentName 'phases'
	AddToLifeCycle	'Release LifeCycle' $environmentName 'Regression Testing'	
}