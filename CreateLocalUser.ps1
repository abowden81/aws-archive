Param (
 [string]$environment
)

if (($environment.Contains('dev')) -and (!$environment.Contains('00')))
{   
    Write-Host 'Create Developer account'
    $compName = 'WinNT://' + $env:COMPUTERNAME    
    $CompObject = [ADSI] $compName

    $NewObj = $CompObject.Create('User','Developer')
    $NewObj.SetPassword('Password1')
    $NewObj.setInfo()

    Write-Host 'Assign to Administrator group'
    $AdminGroup = $compName + '/Administrators,group'
    $AdminGroupObj = [ADSI] $AdminGroup
    $User = $compName + '/Developer,user'   
    $AdminGroupObj.Add($User)
}
elseif (!($environment.Contains('prd')))
{
	 Write-Host 'Create Administrator account'
    $compName = 'WinNT://' + $env:COMPUTERNAME    
    $CompObject = [ADSI] $compName

    $NewObj = $CompObject.Create('User','Administrator')
    $NewObj.SetPassword('t3rr4f0rm!')
    $NewObj.setInfo()

    Write-Host 'Assign to Administrator group'
    $AdminGroup = $compName + '/Administrators,group'
    $AdminGroupObj = [ADSI] $AdminGroup
    $User = $compName + '/Administrator,user'   
    $AdminGroupObj.Add($User)
}