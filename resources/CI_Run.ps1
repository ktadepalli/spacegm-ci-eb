

Param(
    [Parameter(Mandatory=$true)]
  
    [String]
    $userName,

    [Parameter(Mandatory=$true)]
    [String]
    $password,

    [Parameter(Mandatory=$true)]
    [String]
    $appname,

    [Parameter(Mandatory=$true)]
    [String]
    $Artifactory


)


try
{
#$userName = 'admin'                                
#$password = 'admin123'
#$appname = "Dotnet"
#$Artifactory ="http://172.20.53.96:8081/repository/Zip"

echo $userName
echo $password
echo $appname
echo $Artifactory




$time=Get-Date -format "yyyyMMdd_mmss"



#$rv="$appname-$time.zip"
#echo "  Revision $rv"

#$rv|Add-Content .\resources\revision.txt
#copy-item .\resources\* .\publish\

echo "  Compressing zip......." `n
compress-archive -path .\publish\* -destinationpath .\pkg.zip -update -compressionlevel optimal -ErrorAction Stop
echo "  Compressing done!!" `n

echo "  Uploading to Artifactory......."


$uri = "$Artifactory/$appname-$time.zip"
$SOURCE = ".\pkg.zip" 
$pwdSecureString = ConvertTo-SecureString -Force -AsPlainText $password
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $pwdSecureString


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


Invoke-RestMethod -Uri $uri -Method  put -InFile $SOURCE -Credential $cred -ErrorAction Stop

echo "  Uploaded Successfully!!"

$rv="$appname-$time.zip"

echo "  Revision $rv"

$rv|Add-Content .\resources\revision.txt


echo "  compressing runfiles"
compress-archive -path .\resources\* -destinationpath .\runfiles.zip -update -compressionlevel optimal -ErrorAction Stop

echo "  compressed Successfully"


}
catch
{
 Write-Host "ERROR: Failed!!" -ForegroundColor Red `n
    
 Write-Host $_.Exception.Message`n -ForegroundColor Red
}

