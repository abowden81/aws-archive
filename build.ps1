Param (
	[string]$Stack = '.\'
)

#Helper function to transform external file to json ready format
function TransformTextToJson([string]$fullPath)
{
	$outputString = ""
	Get-Content -Path $fullPath | ForEach-Object {
		if (-Not (($outputString -eq "{") -or ($outputString -eq "},") -or ($outputString -contains '"')))	{			
			$outputString += '"' + $_ + '\n",'
		}
	}
	
	if ($outputString.Length -lt 1)
	{
		return ""
	}

	return $outputString.Remove($outputString.Length - 1).Replace("`t"," ")
}

#================================================================================================
# Main
#================================================================================================
#Constant variables
$jpPath = "JsonTool\jq.exe"
$buildResultFile = "buildResult.template"
$outputDir = "Output\"
$mergeResult = "merged.template"

#1. Clean up old/previous generated templates
Write-Host "Clean up old merged template .."
Remove-Item -Path ".\*.template*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ($outputDir + $buildResultFile) -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Fnished clean up"

#2. Ensure that we got Output directory
New-Item -ItemType Directory -Force -Path $outputDir

#3. Get list of all template files in solution directory
$templateList = New-Object System.Collections.Generic.List``1[System.String]

Get-ChildItem -Recurse -Include "*.template" -Exclude merge.template -Path $Stack | Where-Object { $_.Attributes -ne "Directory" } |
ForEach-Object {
	$templateList.Add($_.Directory.Name.ToString() + "\" + $_.Name.ToString())
}

#4. Merge all template files without external scripts from step 3
Write-Host "Found " $templateList.Count "in" $Stack "start merge them ..."
Write-Host "Merging template files ..." $templateList.Count
if ($templateList.Count -gt 1)
{
	$fileTemp = $templateList[0]
	for ($i = 1; $i -lt $templateList.Count; $i++)
	{
		
		#4.1. Validate template file using jq tool
		try
		{
			Write-Host "Validing file" $templateList[$i]
			& $jpPath '.' $templateList[$i] > $null
		}
		catch 
		{
			Write-Error "MERGING ERROR :" $_.Exception.Message
		}
		Write-Host "Passed"
		
		#4.2. Merging
		Write-Host "Merging " $fileTemp "with" $templateList[$i]
		& $jpPath -s ".[0] * .[1]" $fileTemp $templateList[$i] | Out-File ($mergeResult + $i)
		
		#4.3. Save mergin result content to Output directory
		$mergeContent = Get-Content ($mergeResult + $i)
		Set-Content -Path ($mergeResult + $i) $mergeContent
		Write-Host "Finished merge"
		
		$fileTemp = $mergeResult + $i
	}
	
	Move-Item (".\" + ($mergeResult + ($templateList.Count - 1))) ($outputDir + $buildResultFile) -Force
	
	#Clean up generate temp templates	
	Remove-Item -Path ".\*.template*" -Recurse -Force -ErrorAction SilentlyContinue -Exclude $buildResultFile
}

#5. Embed external scripts to build result step 4
if (Test-Path -Path ($outputDir + $buildResultFile))
{
	#Add external script contents	
	Write-Host "Writing external script contents ..."
	Get-ChildItem $Stack -Include "*.sh", "*.ps1", "*.js" -Exclude "build.ps1" -Recurse |
	Where-Object { $_.Attributes -ne "Directory" } |
	ForEach-Object	{
		$buildResultContent = Get-Content ($outputDir + $buildResultFile)
		
		if ($buildResultContent)
		{
			Write-Host "Replacing" ('"#' + $_.Name + '"')
			$replaceContent = TransformTextToJson $_.FullName
			$buildReplaced = $buildResultContent.Replace(('"#' + $_.Name + '"'), $replaceContent)
			Set-Content -Path ($outputDir + $buildResultFile) -Value $buildReplaced
		}
	}
}

Write-Host "Finished writing"


