function Preparation()
{
	#Shutdown IIS
	iisreset /stop

	#Stop worker service?

	#Clean rubbish files
	Remove-Item D:\SmartInspectLogs\* -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\Web\Shared\downloads\* -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\Web\Shared\uploads\*.* -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\Web\Shared\multipay\* -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\FileUploads\* -Recurse -Force -ErrorAction SilentlyContinue 
	Remove-Item D:\Octopus\*.config -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\cert\* -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\Installers\* -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\Octopus\Files\* -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item D:\Octopus\Logs\* -Recurse -Force -ErrorAction SilentlyContinue 
}


function LoadHashTable([string] $hashTextPath)
{
	$result = @{}
	$reader = [System.IO.File]::OpenText($hashTextPath)
	try
	{
		while($null -ne ($line = $reader.ReadLine())) {
		$key,$value = $line.split('|=>',2)
		$result.Add($key, $value.Replace('=>',''))
		}
	}
	catch {
		Write-Host $_.Exception.Message
	}
	finally
	{
		$reader.Close()
	}
	return $result
}

Preparation

#=========================================================================================#
#File transformation
$filepath = Resolve-Path 'transformation.txt'
$fileTransformationHash = LoadHashTable $filepath

Get-ChildItem $Path -Include '*.config', '*.asa', '*.sic', '*.js', '*.asp', '*.cshtml', '*.xml' -Recurse |
Where-Object { $_.Attributes -ne 'Directory' } |
ForEach-Object {
Try
 {
  if ($_.Name.Contains('.PRODUCTION.'))
  {
	  Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue	  
  }
  elseif ($_.Name.Contains('.Prod-OFX.'))
  {
	  Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue	  
  }
  else {
	  $fileFullPath = $_.FullName
	  $fileContent = Get-Content -Encoding UTF8 -LiteralPath $fileFullPath
	  $replaced = $false
	  foreach($oldString in $fileTransformationHash.Keys)  
	  {	 
			if ($fileContent | Select-String -Pattern $oldString)
			{
				$newString = $fileTransformationHash[$oldString]
				if ($newString -eq $null)
				{
					$newString = ''
				}
				Write-Host 'Replace' $oldString 'by' $newString 'found in' $fileFullPath
				$fileContent = $fileContent -replace $oldString, $newString
				$replaced = $true
			}
		}
		if ($replaced)
		{   
			Set-Content $fileContent -Encoding UTF8 -Path $fileFullPath
		}
		}  
   
 }
 Catch
 {
  Write-Host 'ERROR:' $_.Exception.Message  ' while finding and replacing file' $fileFullPath
 }
}
Write-Host 'Done file replacing'

#=========================================================================================#
Write-Host 'Transforming IIS host header ...'

$fileIISpath = Resolve-Path 'IISHostHeadertransformation.txt'
$fileIISTransformationHash = LoadHashTable $fileIISpath
Try
{	
	Import-module WebAdministration

	#Remove SSL Bindings
	Get-ChildItem IIS:\SslBindings| Remove-Item

	#Remove local machine certificates
	$sslBindings = Get-ChildItem IIS:\SslBindings
	foreach($binding in $sslBindings)
	{
		$t = $binding.Thumbprint
		Remove-Item cert:\LocalMachine\My\$t -Force -ErrorAction SilentlyContinue
		Write-Host $binding
	}

	$selfSignedCertificae = Get-ChildItem cert:\LocalMachine\MY | Where-Object {$_.Subject -eq 'CN=*'} | Select-Object -First 1
	if ($selfSignedCertificae -eq $null)
	{
		 $selfSignedCertificae = New-SelfSignedCertificate -DnsName '*' -CertStoreLocation Cert:\LocalMachine\My
	}
	$Websites = Get-ChildItem IIS:\\Sites
	foreach ($Site in $Websites)
	{    
    	$siteName = $Site.name
    	Write-Host 'Working on site ... ' $siteName
		$wsbindings = (Get-ItemProperty -Path IIS:\\Sites\\$siteName -Name Bindings)    
    	for ($i = 0; $i -lt ($wsbindings.Collection).length; $i++)
		{
			try {
				$bindingInformation = ($wsbindings.Collection[$i]).bindingInformation

				#Transform Hostheader
				foreach($hostheader in $fileIISTransformationHash.Keys)  
  				{	 
					if ($bindingInformation | Select-String -Pattern $hostheader)
					{
						  $newHostHeader = $fileIISTransformationHash[$hostheader]
						  if ($newHostHeader -eq $null)
						  {
							  Write-Host 'Remove binding' $hostheader
							  Get-WebBinding -Name $siteName -HostHeader $hostheader | Remove-WebBinding
							  continue 
						  }
						  else {
							Write-Host 'Replace hostheader' $hostheader 'by' $newHostHeader
						  	$bindingInformation = $bindingInformation -replace $hostheader,$newHostHeader  
						  }
					}
				}
				
				#Set new host header
				$port = ($bindingInformation -split ':')[1]
				$HostName = ($bindingInformation -split ':')[-1]
				($wsbindings.Collection[$i]).bindingInformation = $bindingInformation				
				Set-ItemProperty -Path IIS:\\Sites\\$siteName -Name Bindings -Value $wsbindings

				#Trasnform SSL bindings
				if ($port -eq '443')
				{
					Write-Host 'Binding' $HostName 'to SSL ' $selfSignedCertificae.Thumbprint
					Get-WebBinding -Name $siteName -Port 443 | Remove-WebBinding
					New-WebBinding -Name $siteName -Port 443 -SslFlags 0 -Protocol https -HostHeader $HostName -Force -ErrorAction SilentlyContinue
					New-Item -Path IIS:\SslBindings\*!443!$HostName -Value $selfSignedCertificae -SSLFlags 0 -Force -ErrorAction SilentlyContinue
				}
			}
			catch [System.Exception] {				
			}
			
    	}
	}
}
Catch
{
 Write-Host 'ERROR find and replace IIS host header : ' $_.Exception.Message
}
Write-Host 'Done IIS host header replacing'

#=========================================================================================#

Write-Host 'Start find and replacing DNS Suffix ...'
try
{
 	$NIC = [wmiclass]'Win32_NetworkAdapterConfiguration'
 	$privateSuffix = '00.dev.ofx.private.'
 	$publicSuffix = '00.dev.ofx.com.'
 	$NIC.SetDNSSuffixSearchOrder($privateSuffix + ',' + $publicSuffix)
}
catch
{
 	Write-Host 'ERROR find and replace DNS Suffix :' $_.Exception.Message
}

Write-Host 'Done replacing DNS Suffix'

Write-Host 'Flushing DNS ...'
Start-Sleep -s 60
Write-Host 'Finish flushing DNS'

ipconfig /flushdns
Write-Host 'Restart IIS ..'
Write-Host 'Finished restarting IIS'


#=========================================================================================#
Write-Host 'AMI prepration'

# Sets EC2 handle user data to enabled so we can bake the AMI
Stop-Service -Name 'cfn-hup'
$configfile = 'C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml'
$config = (Get-Content $configfile) -as [xml]
($config.Ec2ConfigurationSettings.Plugins.Plugin | Where-Object Name -eq 'Ec2HandleUserData').State = 'Enabled'

# Sets Administrator password to reset upon sysprep
$config.Save($configfile)

# OS Cleanup tasks for AMI bake prep
# Stop Windows Update to perform purge on Downloaded Windows Updates (to save dir space)
Stop-Service -Name 'wuauserv'

Write-Host 'Finished prepration'

#=========================================================================================#
Write-Host 'Cleaning up'
#Clean up Files
try {
	Remove-Item C:\Windows\SoftwareDistribution\* -Recurse -Force -ErrorAction SilentlyContinue	
	
	Remove-Item $filepath -Recurse -Force -ErrorAction SilentlyContinue 
	Remove-Item $fileIISpath -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item $PSScriptRoot\*.ps1 -Force -ErrorAction SilentlyContinue 
}
catch [System.Exception] {	
}
Write-Host 'Finished clean up'

#=========================================================================================#
#Write-Host 'Shutting down'
#Shutdown
#shutdown -s -t 10 -f
