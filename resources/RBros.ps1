#----------------------------------------------------------------------------------------------------------------------------------------------------
# Author : Kenani Tadepalli
# Description: This is a generic script for all IIS deployements.
# Usage: please supply below variables in GOCD -> jobs -> tasks [powershell RBros.ps1 %parm1% %parm2% %parm3% %param4% ....]
# %GO_ENVIRONMENT_NAME% %GO_SERVER_URL% %GO_PIPELINE_NAME% %GO_STAGE_NAME% %GO_PIPELINE_COUNTER% %AppName% %AppPool% %BackupFolder% %IIS_Physical_Dir% %ConfigName% %Artifactory% %Version% %emails%
#----------------------------------------------------------------------------------------------------------------------------------------------------



Param(
    
    [Parameter(Mandatory=$true)]
    [String]
    $Deploy_Env,
	
	[Parameter(Mandatory=$true)]
    [String]
    $goserver,
    
    [Parameter(Mandatory=$true)]
    [String]
    $pipelinename,
    
    [Parameter(Mandatory=$true)]
    [String]
    $Jobname,
    
     [Parameter(Mandatory=$true)]
    [String]
    $JobID,
    
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
    $Config,
    
    [Parameter(Mandatory=$true)]
    [String]
    $Artifactory,
    
     [Parameter(Mandatory=$true)]
    [String]
    $Version,
    
    [Parameter(Mandatory=$true)]
    [array]
    $emails
    
)



cls

#SECTION: Generate log ------------------------>


   $logFile = ".\Pipeline.log"               #<-----"CHANGE the logfile location as required"
   $logLevel = "DEBUG" # ("DEBUG","INFO","WARN","ERROR","FATAL") 
   $logSize = 1mb # 30kb 
   $logCount = 10 
   # end of settings 
      
   function Write-Log-Line ($line) { 
       Add-Content $logFile -Value $Line 
        Write-Host $Line 
    } 
      
   Function Write-Log { 
       [CmdletBinding()] 
       Param( 
       [Parameter()] 
       [string] 
       $Message, 
        
       [Parameter()] 
       [String] 
       $Level = "DEBUG" 
       ) 
      
       $levels = ("DEBUG","INFO","WARN","ERROR","FATAL","") 
       $logLevelPos = [array]::IndexOf($levels, $logLevel) 
       $levelPos = [array]::IndexOf($levels, $Level) 
       $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss:fff") 
      
       if ($logLevelPos -lt 0){ 
           Write-Log-Line "$Stamp ERROR Wrong logLevel configuration [$logLevel]" 
       } 
        
       if ($levelPos -lt 0){ 
           Write-Log-Line "$Stamp ERROR Wrong log level parameter [$Level]" 
       } 
       # if level parameter is wrong or configuration is wrong I still want to see the  
       # message in log 
       if ($levelPos -lt $logLevelPos -and $levelPos -ge 0 -and $logLevelPos -ge 0){ 
           return 
       }    
       $Line = "$Stamp $Level $Message" 
       Write-Log-Line $Line 
   } 

#SECTION: Generate log -----------------------x




#SECTION: Deployment -------------------------->

try
{

echo "-------------variables Defined--------------------" `n

echo "AppName:           $AppName " 
echo "AppPool:           $AppPool "  
echo "BackupFolder:      $BackupFolder"  
echo "IIS_Physical_Dir:  $IIS_Dir "  
echo "ConfigName:        $Config " `n

$Time=get-date -Format ddmmyyyy_mmss


     Remove-Item -Force .\Pipeline.log -ErrorAction SilentlyContinue
     Write-Log "Starting Deployment...." "INFO"


echo "---------------------------------"
echo "STEP1: Download Package"
echo "---------------------------------"

    $stage="STEP1: Download Package"

#$get_package= "$AppName-$version.zip"
$get_package= "$version.zip"

echo "$get_package"
echo "$Artifactory/$get_package"

Invoke-RestMethod -Uri "$Artifactory/$get_package" -OutFile ".\$get_package" -ErrorAction Stop
Write-Log "Package details :$get_package" "INFO"
Write-Log "$stage --- PASSED" "INFO"


echo "---------------------------------"
echo "STEP2: Stop AppPool $AppPool"
echo "---------------------------------"

      $stage = "STEP2: Stop AppPool $AppPool"

      Import-Module WebAdministration
      
      echo "  * Stopping... AppPool $AppPool"
      Stop-WebAppPool -Name $AppPool -ErrorAction SilentlyContinue
      $status=(Get-ChildItem IIS:\AppPools\| where {$_.name -eq $AppPool}).state 
      echo "  * Stopped AppPool *Status $status"

        Write-Log "$stage --- PASSED" "INFO"
      
echo "---------------------------------"
echo "STEP3: Creating... Backup"
echo "---------------------------------"

       $stage = "STEP3: Creating... Backup"

      if(Test-Path -Path $IIS_Dir)
      {

      if (Test-Path -path $BackupFolder){echo "* Backpath Folder already created"}else{mkdir $BackupFolder}

      echo "  * compressing.."
      compress-archive -path $IIS_Dir\* -destinationpath $BackupFolder\$AppName_$Time -update -compressionlevel optimal -ErrorAction Stop
      echo "  * Backup Created!!"
      
      #if backupfolder has more than 5 files it will delete based on old files
      gci $BackupFolder -Recurse| where{-not $_.PsIsContainer}| sort CreationTime -desc | select -Skip 10| Remove-Item -Force
      
      
      }
      else
      {
      echo "  *skipping backup"
      }


       Write-Log "$stage --- PASSED" "INFO"
    


echo "---------------------------------"
echo "STEP4: Cleanup Physicaldir: $IIS_Dir"
echo "---------------------------------"

      $stage = "STEP4: Cleanup Physicaldir: $IIS_Dir"

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
      
      Write-Log "$stage --- PASSED" "INFO"

echo "---------------------------------"
echo "STEP5: Extact and Deploy"
echo "---------------------------------"

     $stage = "STEP5: Extact and Deploy"

      echo "  * Extracting..."
      Expand-Archive -LiteralPath .\$get_package -DestinationPath $IIS_Dir -ErrorAction Stop
      echo "  * Package extracted!!"
      
     
     Write-Log "$stage --- PASSED" "INFO"


echo "---------------------------------"
echo "STEP6: Copy env. config"
echo "---------------------------------"

       $stage = "STEP6: Copy env. config"

       echo "  * Copying config file..."
       
       $Configpath = "$IIS_Dir\Config_GOCD\$config"
       
       Copy-Item $Configpath $IIS_Dir\web.config -Force -ErrorAction Stop
       echo "  * Copied successfully"

    Write-Log "$stage --- PASSED" "INFO"

echo "---------------------------------"
echo "STEP7: Start AppPool $AppPool"
echo "---------------------------------"

        $stage = "STEP7: Start AppPool $AppPool"
      
      echo "  * Starting... AppPool $AppPool !!"
      Start-WebAppPool -Name $AppPool -ErrorAction Stop
      $status=(Get-ChildItem IIS:\AppPools\| where {$_.name -eq $AppPool}).state 
      echo "  * Status:$status * Started successfully!!"

     Write-Log "$stage --- PASSED" "INFO"

echo "---------------------------------"
Write-Host " *** Deployment looks good!!***" -ForegroundColor green
echo "---------------------------------"

     $stage = " *** Deployment looks good!!***"
     
     Write-Log "$stage" "INFO"
        
$result = "SUCCESS"
$depstatus = "Deployment looks good!!"

}
 catch
{
#For log and email--->
 $result ="FAILED"
 Write-log -Message "Failed at this step : $stage" "ERROR" 
 Write-log -Message "$($_.Exception.Message)" "ERROR" 
 $depstatus = "ERROR: Failed at : $stage"
#For log and email---x

 Write-Host "ERROR: Failed at this step : $stage" -ForegroundColor Red `n    
 Write-Host $_.Exception.Message`n -ForegroundColor Red

}
Finally
{

#SECTION: Deployment -----------------------x




#SECTION: Email sending --------------------->



$emailbody=@"
Hi,

Please find the deployment details,

----------------------------------------------------------

Status        : $result 
URL           : $goserver/pipelines/$pipelinename/$JobID/$Jobname/1
PackageID     : $get_package
Deploy status : $depstatus

----------------------------------------------------------

Thanks,
DevopsTeam.
"@


$email = ($emails -join ",")

$uname='devops.support@alerts.valuelabs.com'
$passwd='Sonic@789'
$fromaddress = "devops.support@alerts.valuelabs.com"
$toaddress = $email
$Subject = "GOCD Deployment $Result - App: $Appname on $Deploy_Env environment"
$body = $emailbody
$attachment = ".\pipeline.log"
$smtpserver = "mx5.alerts.valuelabs.com"


$message = new-object System.Net.Mail.MailMessage
$message.From = $fromaddress
$message.To.Add($toaddress)
$message.Subject = $Subject
$attach = new-object Net.Mail.Attachment($attachment)
$message.Attachments.Add($attach)
$message.body = $body
$smtp = new-object Net.Mail.SmtpClient($smtpserver)
$smtp.Credentials = New-Object System.Net.NetworkCredential($uname, $passwd);
$smtp.Send($message)
$attach.Dispose()

#
#Hi,
#
#Please find the deployment details,
#
#----------------------------------------------------------
#
#Status        : $result 
#URL           : $goserver/pipelines/$pipelinename/$JobID/$Jobname/1
#PackageID     : $get_package
#Deploy status : $depstatus
#
#----------------------------------------------------------
#
#Thanks,
#DevopsTeam.
#
#"@
#
#
#$userName = 'devops.support@alerts.valuelabs.com'                                
#$password = 'Sonic@789'
#$pwdSecureString = ConvertTo-SecureString -Force -AsPlainText $password
#$credo = New-Object -TypeName System.Management.Automation.PSCredential `
#    -ArgumentList $userName, $pwdSecureString
#Send-MailMessage -To "kenanibabu.tadepalli@valuelabs.com" -From "devops.support@alerts.valuelabs.com"  -Subject "$Result - Deployment status of App: $Appname on $Deploy_Env env" -Attachments .\pipeline.log -Body $emailbody -Credential $credo -SmtpServer "mx5.alerts.valuelabs.com" -Port 587
#
#SECTION: Email sending ---------------------x

if ($result -eq "FAILED"){exit 1}

}