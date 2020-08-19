pipeline {
    agent {
        label 'windows01'
    }
    stages {
        stage ('cleanWS-checkout-lookup') {
            steps {
                cleanWs()
                checkout scm
            }
        }
        stage ('Build') {
            steps {
        powershell '''
            
             dotnet restore
             dotnet build -c Release -o .\\Publish
             dotnet publish -c release -o .\\Publish --no-restore
             gci .\\publish
             mkdir .\\Publish\\Config_GOCD;
             Copy-Item .\\Config_GOCD\\* .\\Publish\\Config_GOCD -recurse
               '''
            }
        }


      stage('Trigger GOCD') {
       when {
                branch 'master'
            }
            steps {
             
    powershell '''
    
          $userName = 'admin'                                
          $password = 'admin123'
          $appname = "Dotnet"
          $Artifactory ="http://172.20.53.96:8081/repository/Zips"
          $PipelineName="RBros"
          
          
          try
          {
          
          $time=Get-Date -format "yyyyMMdd_mmss"

          echo "  Compressing zip......." `n
          compress-archive -path .\\publish\\* -destinationpath .\\pkg.zip -update -compressionlevel optimal -ErrorAction Stop
          echo "  Compressing done!!" `n
          
          echo "  Uploading to Artifactory......."
          
          
          $uri = "$Artifactory/$appname-$time.zip"
          $SOURCE = ".\\pkg.zip" 
          $pwdSecureString = ConvertTo-SecureString -Force -AsPlainText $password
          $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $pwdSecureString
          
          
          [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
          
          
          Invoke-RestMethod -Uri $uri -Method  put -InFile $SOURCE -Credential $cred -ErrorAction Stop
          
          echo "  Uploaded Successfully!!"
          
          $pkgID="$appname-$time"
          
          echo "  PakageID $pkgID"


          }
          catch
          {
           Write-Host "ERROR: Failed!!" -ForegroundColor Red `n
              
           Write-Host $_.Exception.Message`n -ForegroundColor Red
           Exit 1
          }
          

          try
          {
          $Url = "http://10.100.52.74:8153/go/api/pipelines/$PipelineName/schedule"
          $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
          $headers.Add("Accept","application/vnd.go.cd.v1+json")
          $headers.Add("X-GoCD-Confirm","true")
          $headers.Add("Content-Type","application/json")

$b=@"
{"environment_variables": [{"name": "version", "secure": false,"value": $pkgID}]}
"@

          $result=invoke-restmethod -uri $url -header $headers -method post  -Body $b -ErrorAction Stop
          Write-Host "$result"
          }
          catch
          {
           Write-Host "ERROR: Failed at this step :"    
           Write-Host $_.Exception.Message
           exit 1
          
           }
    '''
                
            }
        }


    }
	    post {
        always {
         script {
          if (GIT_BRANCH == 'master'){
               emailext attachLog: true,
               to: 'kenanibabu.tadepalli@valuelabs.com ,cc:sudhakar.pulavarthi@valuelabs.com',
               body: "${currentBuild.currentResult}: Job ${env.JOB_NAME} build ${env.BUILD_NUMBER}\n ",
               recipientProviders: [developers(), requestor()],
               subject: "Jenkins Build ${currentBuild.currentResult}: Job ${env.JOB_NAME}"
       }}
               }
           }
	    
}

