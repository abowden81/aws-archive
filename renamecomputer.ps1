#######################################
# Script used to rename each instance to their corresponding instance id
#######################################

$idgroup = Invoke-WebRequest http://169.254.169.254/latest/meta-data/instance-id -UseBasicParsing
$idinstance = $idgroup.content

Write-Host 'Renaming instance to ' $idinstance

Rename-Computer -newname $idinstance