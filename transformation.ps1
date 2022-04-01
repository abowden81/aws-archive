Param (
 [string]$oldString,
 [string]$newString,
 [string]$Path = 'D:'
)

Write-Host 'Start find and replacing in ' $Path ' files old string =' $oldString ' and new string =' $newString '...'

Get-ChildItem $Path -Include '*.config', '*.asa', '*.sic', '*.js', '*.asp', '*.cshtml', '*.xml' -Recurse |
Where-Object { $_.Attributes -ne 'Directory' } |
ForEach-Object {
Try
 {
  $fileFullPath = $_.FullName
  $fileContent = Get-Content -Encoding UTF8 -LiteralPath $fileFullPath  
  if ($fileContent | Select-String -Pattern $oldString)
  {
	   Write-Host 'Replace' $oldString 'by' $newString 'found in' $fileFullPath
	   $fileContentReplace = $fileContent -replace $oldString, $newString | Set-Content -Encoding UTF8 -Path $fileFullPath
  }
 }
 Catch
 {
  Write-Host 'ERROR:' $_.Exception.Message  ' while finding and replacing file' $fileFullPath
 }
}
Write-Host 'Done file replacing'

Write-Host 'Start find and replacing in IIS host header ...'
Try
{
 Import-Module WebAdministration
 $Websites = Get-ChildItem IIS:\\Sites
 foreach ($Site in $Websites)
 {
  $siteName = $Site.name
  $wsbindings = (Get-ItemProperty -Path IIS:\\Sites\\$siteName -Name Bindings)
  for ($i = 0; $i -lt ($wsbindings.Collection).length; $i++)
  {
   if ((($wsbindings.Collection[$i]).bindingInformation).Contains($oldString))
   {
    Write-Host 'Found matching binding' ($wsbindings.Collection[$i]).bindingInformation;
    ($wsbindings.Collection[$i]).bindingInformation = ($wsbindings.Collection[$i]).bindingInformation -replace $oldString, $newString;
   }
  }

  Set-ItemProperty -Path IIS:\\Sites\\$siteName -Name Bindings -Value $wsbindings
 }
}
Catch
{
 Write-Host 'ERROR find and replace IIS host header : ' $_.Exception.Message
}
Write-Host 'Done IIS host header replacing'

Write-Host 'Start find and replacing DNS Suffix ...'
try
{
 $NIC = [wmiclass]'Win32_NetworkAdapterConfiguration'
 $privateSuffix = $newString + '.ofx.private.'
 $publicSuffix = $newString + '.ofx.com.'
 $NIC.SetDNSSuffixSearchOrder($privateSuffix + ',' + $publicSuffix)
}
catch
{
 Write-Host 'ERROR find and replace DNS Suffix :' $_.Exception.Message
}
Write-Host 'Done replacing DNS Suffix'