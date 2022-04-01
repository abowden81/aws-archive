Param (
	[string]$apitoken,
	[string]$roomid,
	[string]$messageText,
	[string]$computerId,
	[string]$environment

)
$color = 'green'
#TODO : How to detect error during cfn-int
#$messageText = '(failed)'
#$color = 'red'
$messageValue = 'CloudFormation finished on computer ' + $computerId + ' environement ' + $environment + ':' + $messageText
$message = New-Object PSObject
$message | Add-Member -MemberType NoteProperty -Name color -Value $color
$message | Add-Member -MemberType NoteProperty -Name message -Value $messageValue
$message | Add-Member -MemberType NoteProperty -Name notify -Value $true
$message | Add-Member -MemberType NoteProperty -Name message_format -Value text
#Do the HTTP POST to HipChat
$uri = 'https://api.hipchat.com/v2/room/' + $roomid + '/notification?auth_token='+ $apitoken
$postBody = ConvertTo-Json -InputObject $message
$postStr = [System.Text.Encoding]::UTF8.GetBytes($postBody)

$webRequest = [System.Net.WebRequest]::Create($uri)
$webRequest.ContentType = 'application/json'
$webrequest.ContentLength = $postStr.Length
$webRequest.Method = 'POST'

$requestStream = $webRequest.GetRequestStream()
$requestStream.Write($postStr, 0, $postStr.length)
$requestStream.Close()

[System.Net.WebResponse]$resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()

[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
$sr.ReadToEnd()

Write-Host 'Clean up ...'
Remove-Item -Path D:\\*.ps1 -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path D:\\ -Include 'TransformProdToGolden.*' -File -Recurse | foreach { $_.Delete()}

Write-Host 'Rebooting instance for hostname change to take effect'
shutdown -r -t 10 -f