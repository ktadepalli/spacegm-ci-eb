Param(
    [Parameter(Mandatory=$true)]
  
    [String]
    $AppName,

    [Parameter(Mandatory=$true)]
    [String]
    $AppPool,

    [Parameter(Mandatory=$true)]
    [String]
    $BackupFolder,

    [Parameter(Mandatory=$true)]
    [String]
    $IIS_Dir,


    [Parameter(Mandatory=$true)]
    [String]
    $Config

)

#Variable Declartion
#====================
cls
#$AppName="RB"
#$AppPool="RB-pool"
#$BackupFolder = "C:\Backup_GOCD\$AppName"
#$IIS_Dir="C:\RB_Sites\appdir"
#$Config="web.dev.config"

#====================
$Time=get-date -Format ddmmyyyy_mmss
try
{

echo "-------------variables Defined--------------------" `n

echo "AppName:           $AppName " 
echo "AppPool:           $AppPool "  
echo "BackupFolder:      $BackupFolder"  
echo "IIS_Physical_Dir:  $IIS_Dir "  
echo "ConfigName:        $Config " `n

$get_rev_zip=Get-Content .\revision.txt

echo "$get_rev_zip"
echo "http://172.20.53.96:8081/repository/Zip/$get_rev_zip"

Invoke-RestMethod -Uri "http://172.20.53.96:8081/repository/Zip/$get_rev_zip" -OutFile ".\$get_rev_zip"




echo "---------------------------------"
echo "STEP1: Stop AppPool $AppPool"
echo "---------------------------------"
      Import-Module WebAdministration
      
      echo "  * Stopping... AppPool $AppPool"
      Stop-WebAppPool -Name $AppPool -ErrorAction SilentlyContinue
      $status=(Get-ChildItem IIS:\AppPools\| where {$_.name -eq $AppPool}).state 
      echo "  * Stopped AppPool *Status $status"

echo "---------------------------------"
echo "STEP2: Creating... Backup"
echo "---------------------------------"
      if(Test-Path -Path $IIS_Dir)
      {

      if (Test-Path -path $BackupFolder){echo "* Backpath Folder already created"}else{mkdir $BackupFolder}

      echo "  * compressing.."
      compress-archive -path $IIS_Dir\* -destinationpath $BackupFolder\$AppName_$Time -update -compressionlevel optimal -ErrorAction Stop
      echo "  * Backup Created!!"
      }
      else
      {
      echo "  *skipping backup"
      }



echo "---------------------------------"
echo "STEP3: Cleanup Physicaldir: $IIS_Dir"
echo "---------------------------------"

     if(Test-Path $IIS_Dir)
      {
      
      echo "  * Deleting.."
      Remove-Item $IIS_Dir -Recurse -Force -Confirm:$false -ErrorAction Stop
      echo "  * Deleted!!"
      }
      
      echo "  * Creating.."
      New-Item -Path $IIS_Dir -ItemType Directory -Force -ErrorAction Stop
      echo "  * Physicaldir CREATED!!"
      echo "  * Created!!"
      

echo "---------------------------------"
echo "STEP4: Extact and Deploy"
echo "---------------------------------"

      echo "  * Extracting..."
      Expand-Archive -LiteralPath .\$get_rev_zip -DestinationPath $IIS_Dir -ErrorAction Stop
      echo "  * Package extracted!!"
      


echo "---------------------------------"
echo "STEP5: Copy env. config"
echo "---------------------------------"

       echo "  * Copying config file..."
       
       $Configpath = "$IIS_Dir\Config_GOCD\$config"
       
       Copy-Item $Configpath $IIS_Dir\web.config -Force -ErrorAction Stop
       echo "  * Copied successfully"

echo "---------------------------------"
echo "STEP6: Start AppPool $AppPool"
echo "---------------------------------"
      
      echo "  * Starting... AppPool $AppPool !!"
      Start-WebAppPool -Name $AppPool -ErrorAction Stop
      $status=(Get-ChildItem IIS:\AppPools\| where {$_.name -eq $AppPool}).state 
      echo "  * Status:$status * Started successfully!!"

echo "---------------------------------"
Write-Host " *** Deployment looks good!!***" -ForegroundColor green
echo "---------------------------------"

}
 catch
{
 Write-Host "ERROR: Failed at this step" -ForegroundColor Red `n
    
 Write-Host $_.Exception.Message`n -ForegroundColor Red
}





