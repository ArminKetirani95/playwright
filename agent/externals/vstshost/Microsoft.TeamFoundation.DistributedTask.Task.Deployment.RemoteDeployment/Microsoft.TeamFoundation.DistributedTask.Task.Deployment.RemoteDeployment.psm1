<#
    Microsoft.TeamFoundation.DistributedTask.Task.Deployment.RemoteDeployment.psm1
#>

function Invoke-RemoteDeployment
{    
    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory=$true)]
        [string]$environmentName,
        [string]$adminUserName,
        [string]$adminPassword,
        [string]$protocol,
        [string]$testCertificate,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='TagsBlock')]
        [string]$tags,
        [Parameter(ParameterSetName='MachinesPath')]
        [Parameter(ParameterSetName='MachinesBlock')]
        [string]$machineNames,
        [Parameter(Mandatory=$true, ParameterSetName='TagsPath')]
        [Parameter(Mandatory=$true, ParameterSetName='MachinesPath')]
        [string]$scriptPath,
        [Parameter(Mandatory=$true, ParameterSetName='TagsBlock')]
        [Parameter(Mandatory=$true, ParameterSetName='MachinesBlock')]
        [string]$scriptBlockContent,
        [string]$scriptArguments,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='MachinesPath')]
        [string]$initializationScriptPath,
        [string]$runPowershellInParallel,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='MachinesPath')]
        [string]$sessionVariables
    )

    Write-Verbose "Entering Remote-Deployment block"
        
    $machineFilter = $machineNames

    # Getting resource tag key name for corresponding tag
    $resourceFQDNKeyName = Get-ResourceFQDNTagKey
    $resourceWinRMHttpPortKeyName = Get-ResourceHttpTagKey
    $resourceWinRMHttpsPortKeyName = Get-ResourceHttpsTagKey

    # Constants #
    $useHttpProtocolOption = '-UseHttp'
    $useHttpsProtocolOption = ''

    $doSkipCACheckOption = '-SkipCACheck'
    $doNotSkipCACheckOption = ''
    $ErrorActionPreference = 'Stop'
    $deploymentOperation = 'Deployment'

    $envOperationStatus = "Passed"

    # enabling detailed logging only when system.debug is true
    $enableDetailedLoggingString = $env:system_debug
    if ($enableDetailedLoggingString -ne "true")
    {
        $enableDetailedLoggingString = "false"
    }

    function Get-ResourceWinRmConfig
    {
        param
        (
            [string]$resourceName,
            [int]$resourceId
        )

        $resourceProperties = @{}

        $winrmPortToUse = ''
        $protocolToUse = ''


        if($protocol -eq "HTTPS")
        {
            $protocolToUse = $useHttpsProtocolOption
        
            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
            $winrmPortToUse = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId (Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
        
            if([string]::IsNullOrWhiteSpace($winrmPortToUse))
            {
                throw(Get-LocalizedString -Key "{0} port was not provided for resource '{1}'" -ArgumentList "WinRM HTTPS", $resourceName)
            }
        }
        elseif($protocol -eq "HTTP")
        {
            $protocolToUse = $useHttpProtocolOption
            
            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
            $winrmPortToUse = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
        
            if([string]::IsNullOrWhiteSpace($winrmPortToUse))
            {
                throw(Get-LocalizedString -Key "{0} port was not provided for resource '{1}'" -ArgumentList "WinRM HTTP", $resourceName)
            }
        }

        elseif($environment.Provider -ne $null)      #  For standerd environment provider will be null
        {
            Write-Verbose "`t Environment is not standerd environment. Https port has higher precedence"

            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
            $winrmHttpsPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId (Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"

            if ([string]::IsNullOrEmpty($winrmHttpsPort))
            {
                Write-Verbose "`t Resource: $resourceName does not have any winrm https port defined, checking for winrm http port"
                    
                   Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
                   $winrmHttpPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId 
                   Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"

                if ([string]::IsNullOrEmpty($winrmHttpPort))
                {
                    throw(Get-LocalizedString -Key "Resource: '{0}' does not have WinRM service configured. Configure WinRM service on the Azure VM Resources. Refer for more details '{1}'" -ArgumentList $resourceName, "https://aka.ms/azuresetup" )
                }
                else
                {
                    # if resource has winrm http port defined
                    $winrmPortToUse = $winrmHttpPort
                    $protocolToUse = $useHttpProtocolOption
                }
            }
            else
            {
                # if resource has winrm https port opened
                $winrmPortToUse = $winrmHttpsPort
                $protocolToUse = $useHttpsProtocolOption
            }
        }
        else
        {
            Write-Verbose "`t Environment is standerd environment. Http port has higher precedence"

            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
            $winrmHttpPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"

            if ([string]::IsNullOrEmpty($winrmHttpPort))
            {
                Write-Verbose "`t Resource: $resourceName does not have any winrm http port defined, checking for winrm https port"

                   Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
                   $winrmHttpsPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
                   Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"

                if ([string]::IsNullOrEmpty($winrmHttpsPort))
                {
                    throw(Get-LocalizedString -Key "Resource: '{0}' does not have WinRM service configured. Configure WinRM service on the Azure VM Resources. Refer for more details '{1}'" -ArgumentList $resourceName, "https://aka.ms/azuresetup" )
                }
                else
                {
                    # if resource has winrm https port defined
                    $winrmPortToUse = $winrmHttpsPort
                    $protocolToUse = $useHttpsProtocolOption
                }
            }
            else
            {
                # if resource has winrm http port opened
                $winrmPortToUse = $winrmHttpPort
                $protocolToUse = $useHttpProtocolOption
            }
        }

        $resourceProperties.protocolOption = $protocolToUse
        $resourceProperties.winrmPort = $winrmPortToUse

        return $resourceProperties;
    }

    function Get-SkipCACheckOption
    {
        [CmdletBinding()]
        Param
        (
            [string]$environmentName
        )

        $skipCACheckOption = $doNotSkipCACheckOption
        $skipCACheckKeyName = Get-SkipCACheckTagKey

        # get skipCACheck option from environment
        Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with key: $skipCACheckKeyName"
        $skipCACheckBool = Get-EnvironmentProperty -Environment $environment -Key $skipCACheckKeyName 
        Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with key: $skipCACheckKeyName"

        if ($skipCACheckBool -eq "true")
        {
            $skipCACheckOption = $doSkipCACheckOption
        }

        return $skipCACheckOption
    }

    function Get-ResourceConnectionDetails
    {
        param([object]$resource)

        $resourceProperties = @{}
        $resourceName = $resource.Name
        $resourceId = $resource.Id

        Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $environmentName with resource id: $resourceId(Name : $resourceName) and key: $resourceFQDNKeyName"
        $fqdn = Get-EnvironmentProperty -Environment $environment -Key $resourceFQDNKeyName -ResourceId $resourceId 
        Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $environmentName with resource id: $resourceId(Name : $resourceName) and key: $resourceFQDNKeyName"

        $winrmconfig = Get-ResourceWinRmConfig -resourceName $resourceName -resourceId $resourceId
        $resourceProperties.fqdn = $fqdn
        $resourceProperties.winrmPort = $winrmconfig.winrmPort
        $resourceProperties.protocolOption = $winrmconfig.protocolOption
        $resourceProperties.credential = Get-ResourceCredentials -resource $resource	
        $resourceProperties.displayName = $fqdn + ":" + $winrmconfig.winrmPort

        return $resourceProperties
    }

    function Get-ResourcesProperties
    {
        param([object]$resources)

        $skipCACheckOption = Get-SkipCACheckOption -environmentName $environmentName
        [hashtable]$resourcesPropertyBag = @{}

        foreach ($resource in $resources)
        {
            $resourceName = $resource.Name
            $resourceId = $resource.Id
            Write-Verbose "Get Resource properties for $resourceName (ResourceId = $resourceId)"
            $resourceProperties = Get-ResourceConnectionDetails -resource $resource
            $resourceProperties.skipCACheckOption = $skipCACheckOption
            $resourcesPropertyBag.add($resourceId, $resourceProperties)
        }

        return $resourcesPropertyBag
    }

    $RunPowershellJobInitializationScript = {
        function Load-AgentAssemblies
        {
            
            if(Test-Path "$env:AGENT_HOMEDIRECTORY\Agent\Worker")
            {
                Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\*.dll | % {
                [void][reflection.assembly]::LoadFrom( $_.FullName )
                Write-Verbose "Loading .NET assembly:`t$($_.name)"
                }

                Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\Modules\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs\*.dll | % {
                [void][reflection.assembly]::LoadFrom( $_.FullName )
                Write-Verbose "Loading .NET assembly:`t$($_.name)"
                }
            }
            else
            {
                if(Test-Path "$env:AGENT_HOMEDIRECTORY\externals\vstshost")
                {
                    [void][reflection.assembly]::LoadFrom("$env:AGENT_HOMEDIRECTORY\externals\vstshost\Microsoft.TeamFoundation.DistributedTask.Task.LegacySDK.dll")
                }
            }
        }

        function Get-EnableDetailedLoggingOption
        {
            param ([string]$enableDetailedLogging)

            if ($enableDetailedLogging -eq "true")
            {
                return '-EnableDetailedLogging'
            }

            return '';
        }
    }

    $RunPowershellJobForScriptPath = {
        param (
        [string]$fqdn, 
        [string]$scriptPath,
        [string]$port,
        [string]$scriptArguments,
        [string]$initializationScriptPath,
        [object]$credential,
        [string]$httpProtocolOption,
        [string]$skipCACheckOption,
        [string]$enableDetailedLogging,
        [object]$sessionVariables
        )

        Write-Verbose "fqdn = $fqdn"
        Write-Verbose "scriptPath = $scriptPath"
        Write-Verbose "port = $port"
        Write-Verbose "scriptArguments = $scriptArguments"
        Write-Verbose "initializationScriptPath = $initializationScriptPath"
        Write-Verbose "protocolOption = $httpProtocolOption"
        Write-Verbose "skipCACheckOption = $skipCACheckOption"
        Write-Verbose "enableDetailedLogging = $enableDetailedLogging"

        Load-AgentAssemblies

        $enableDetailedLoggingOption = Get-EnableDetailedLoggingOption $enableDetailedLogging
    
        Write-Verbose "Initiating deployment on $fqdn"
        [String]$psOnRemoteScriptBlockString = "Invoke-PsOnRemote -MachineDnsName $fqdn -ScriptPath `$scriptPath -WinRMPort $port -Credential `$credential -ScriptArguments `$scriptArguments -InitializationScriptPath `$initializationScriptPath -SessionVariables `$sessionVariables $skipCACheckOption $httpProtocolOption $enableDetailedLoggingOption"
        [scriptblock]$psOnRemoteScriptBlock = [scriptblock]::Create($psOnRemoteScriptBlockString)
        $deploymentResponse = Invoke-Command -ScriptBlock $psOnRemoteScriptBlock
    
        Write-Output $deploymentResponse
    }

    $RunPowershellJobForScriptBlock = {
    param (
        [string]$fqdn, 
        [string]$scriptBlockContent,
        [string]$port,
        [string]$scriptArguments,    
        [object]$credential,
        [string]$httpProtocolOption,
        [string]$skipCACheckOption,
        [string]$enableDetailedLogging    
        )

        Write-Verbose "fqdn = $fqdn"
        Write-Verbose "port = $port"
        Write-Verbose "scriptArguments = $scriptArguments"
        Write-Verbose "protocolOption = $httpProtocolOption"
        Write-Verbose "skipCACheckOption = $skipCACheckOption"
        Write-Verbose "enableDetailedLogging = $enableDetailedLogging"

        Load-AgentAssemblies

        $enableDetailedLoggingOption = Get-EnableDetailedLoggingOption $enableDetailedLogging
   
        Write-Verbose "Initiating deployment on $fqdn"
        [String]$psOnRemoteScriptBlockString = "Invoke-PsOnRemote -MachineDnsName $fqdn -ScriptBlockContent `$scriptBlockContent -WinRMPort $port -Credential `$credential -ScriptArguments `$scriptArguments $skipCACheckOption $httpProtocolOption $enableDetailedLoggingOption"
        [scriptblock]$psOnRemoteScriptBlock = [scriptblock]::Create($psOnRemoteScriptBlockString)
        $deploymentResponse = Invoke-Command -ScriptBlock $psOnRemoteScriptBlock
    
        Write-Output $deploymentResponse
    }

    $connection = Get-VssConnection -TaskContext $distributedTaskContext

    # This is temporary fix for filtering 
    if([string]::IsNullOrEmpty($machineNames))
    {
       $machineNames  = $tags
    }

    Write-Verbose "Starting Register-Environment cmdlet call for environment : $environmentName with filter $machineNames"
    $environment = Register-Environment -EnvironmentName $environmentName -EnvironmentSpecification $environmentName -UserName $adminUserName -Password $adminPassword -WinRmProtocol $protocol -TestCertificate ($testCertificate -eq "true")  -Connection $connection -TaskContext $distributedTaskContext -ResourceFilter $machineNames
	Write-Verbose "Completed Register-Environment cmdlet call for environment : $environmentName"
	
    Write-Verbose "Starting Get-EnvironmentResources cmdlet call on environment name: $environmentName"
    $resources = Get-EnvironmentResources -Environment $environment

    if ($resources.Count -eq 0)
    {
      throw (Get-LocalizedString -Key "No machine exists under environment: '{0}' for deployment" -ArgumentList $environmentName)
    }

    $resourcesPropertyBag = Get-ResourcesProperties -resources $resources

    $parsedSessionVariables = Get-ParsedSessionVariables -inputSessionVariables $sessionVariables

    if($runPowershellInParallel -eq "false" -or  ( $resources.Count -eq 1 ) )
    {
        foreach($resource in $resources)
        {
            $resourceProperties = $resourcesPropertyBag.Item($resource.Id)
            $machine = $resourceProperties.fqdn
            $displayName = $resourceProperties.displayName
            Write-Host (Get-LocalizedString -Key "Deployment started for machine: '{0}'" -ArgumentList $displayName)

            . $RunPowershellJobInitializationScript
            if($PsCmdlet.ParameterSetName.EndsWith("Path"))
            {
                $deploymentResponse = Invoke-Command -ScriptBlock $RunPowershellJobForScriptPath -ArgumentList $machine, $scriptPath, $resourceProperties.winrmPort, $scriptArguments, $initializationScriptPath, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString, $parsedSessionVariables
            }
            else
            {
                $deploymentResponse = Invoke-Command -ScriptBlock $RunPowershellJobForScriptBlock -ArgumentList $machine, $scriptBlockContent, $resourceProperties.winrmPort, $scriptArguments, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString 
            }

            Write-ResponseLogs -operationName $deploymentOperation -fqdn $displayName -deploymentResponse $deploymentResponse
            $status = $deploymentResponse.Status
				
			if ($status -ne "Passed")
			{             
			    if($deploymentResponse.Error -ne $null)
                {
					Write-Verbose (Get-LocalizedString -Key "Deployment failed on machine '{0}' with following message : '{1}'" -ArgumentList $displayName, $deploymentResponse.Error.ToString())
                    $errorMessage = $deploymentResponse.Error.Message
					return $errorMessage					
                }
				else
				{
					$errorMessage = (Get-LocalizedString -Key 'Deployment on one or more machines failed.')
					return $errorMessage
				}
           }
		   
		    Write-Host (Get-LocalizedString -Key "Deployment status for machine '{0}' : '{1}'" -ArgumentList $displayName, $status)
        }
    }
    else
    {
        [hashtable]$Jobs = @{} 

        foreach($resource in $resources)
        {
            $resourceProperties = $resourcesPropertyBag.Item($resource.Id)
            $machine = $resourceProperties.fqdn
            $displayName = $resourceProperties.displayName
            Write-Host (Get-LocalizedString -Key "Deployment started for machine: '{0}'" -ArgumentList $displayName)

            if($PsCmdlet.ParameterSetName.EndsWith("Path"))
            {
                $job = Start-Job -InitializationScript $RunPowershellJobInitializationScript -ScriptBlock $RunPowershellJobForScriptPath -ArgumentList $machine, $scriptPath, $resourceProperties.winrmPort, $scriptArguments, $initializationScriptPath, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString, $parsedSessionVariables
            }
            else
            {
                $job = Start-Job -InitializationScript $RunPowershellJobInitializationScript -ScriptBlock $RunPowershellJobForScriptBlock -ArgumentList $machine, $scriptBlockContent, $resourceProperties.winrmPort, $scriptArguments, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString                 
            }
            
            $Jobs.Add($job.Id, $resourceProperties)
        }
        While (Get-Job)
        {
            Start-Sleep 10 
            foreach($job in Get-Job)
            {
                 if($job.State -ne "Running")
                {
                    $output = Receive-Job -Id $job.Id
                    Remove-Job $Job
                    $status = $output.Status
                    $displayName = $Jobs.Item($job.Id).displayName
                    $resOperationId = $Jobs.Item($job.Id).resOperationId

                    Write-ResponseLogs -operationName $deploymentOperation -fqdn $displayName -deploymentResponse $output
                    Write-Host (Get-LocalizedString -Key "Deployment status for machine '{0}' : '{1}'" -ArgumentList $displayName, $status)
                    if($status -ne "Passed")
                    {
                        $envOperationStatus = "Failed"
                        $errorMessage = ""
                        if($output.Error -ne $null)
                        {
                            $errorMessage = $output.Error.Message
                        }
                        Write-Host (Get-LocalizedString -Key "Deployment failed on machine '{0}' with following message : '{1}'" -ArgumentList $displayName, $errorMessage)
                    }
                }
            }
        }
    }

    if($envOperationStatus -ne "Passed")
    {
         $errorMessage = (Get-LocalizedString -Key 'Deployment on one or more machines failed.')
         return $errorMessage
    }

}
# SIG # Begin signature block
# MIIoLQYJKoZIhvcNAQcCoIIoHjCCKBoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDvZ3uXMKhqjxqP
# pD9BYnyXygrXbhnvSUzwcypxeAztfKCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
# DkyjTQVBAAAAAAOvMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwOTAwWhcNMjQxMTE0MTkwOTAwWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOS8s1ra6f0YGtg0OhEaQa/t3Q+q1MEHhWJhqQVuO5amYXQpy8MDPNoJYk+FWA
# hePP5LxwcSge5aen+f5Q6WNPd6EDxGzotvVpNi5ve0H97S3F7C/axDfKxyNh21MG
# 0W8Sb0vxi/vorcLHOL9i+t2D6yvvDzLlEefUCbQV/zGCBjXGlYJcUj6RAzXyeNAN
# xSpKXAGd7Fh+ocGHPPphcD9LQTOJgG7Y7aYztHqBLJiQQ4eAgZNU4ac6+8LnEGAL
# go1ydC5BJEuJQjYKbNTy959HrKSu7LO3Ws0w8jw6pYdC1IMpdTkk2puTgY2PDNzB
# tLM4evG7FYer3WX+8t1UMYNTAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQURxxxNPIEPGSO8kqz+bgCAQWGXsEw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMTgyNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAISxFt/zR2frTFPB45Yd
# mhZpB2nNJoOoi+qlgcTlnO4QwlYN1w/vYwbDy/oFJolD5r6FMJd0RGcgEM8q9TgQ
# 2OC7gQEmhweVJ7yuKJlQBH7P7Pg5RiqgV3cSonJ+OM4kFHbP3gPLiyzssSQdRuPY
# 1mIWoGg9i7Y4ZC8ST7WhpSyc0pns2XsUe1XsIjaUcGu7zd7gg97eCUiLRdVklPmp
# XobH9CEAWakRUGNICYN2AgjhRTC4j3KJfqMkU04R6Toyh4/Toswm1uoDcGr5laYn
# TfcX3u5WnJqJLhuPe8Uj9kGAOcyo0O1mNwDa+LhFEzB6CB32+wfJMumfr6degvLT
# e8x55urQLeTjimBQgS49BSUkhFN7ois3cZyNpnrMca5AZaC7pLI72vuqSsSlLalG
# OcZmPHZGYJqZ0BacN274OZ80Q8B11iNokns9Od348bMb5Z4fihxaBWebl8kWEi2O
# PvQImOAeq3nt7UWJBzJYLAGEpfasaA3ZQgIcEXdD+uwo6ymMzDY6UamFOfYqYWXk
# ntxDGu7ngD2ugKUuccYKJJRiiz+LAUcj90BVcSHRLQop9N8zoALr/1sJuwPrVAtx
# HNEgSW+AKBqIxYWM4Ev32l6agSUAezLMbq5f3d8x9qzT031jMDT+sUAoCw0M5wVt
# CUQcqINPuYjbS1WgJyZIiEkBMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGg0wghoJAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPvd2aSF2Ep37PuCnFW7e2ox
# 0cizuB8VazPk++vL6yf0MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAJXEB4Juflo8l008Re3t5KoL7+1Rx2oSSyFYHut8kI5zlCS9SLv8nB5Z5
# xgPaKNr3ToM8nUZle9JOk2BbYHOV6CHB7Du82MqbNauab/h94HopjkuMaoSccs4D
# aE0uxKBBnZmvb8UqZofBWP3ITSAVsDokDV/2161CRp5UOQAEHwMMArSyF1uCUjFi
# ERO6GaPwDCSPjhaIq4LrvqqigZu/0jSn5wNKIuEj/28HmOIiIDJ6Kk1K1e9TiYmC
# 16OvIv70dLeWJT8ojgFDYub1EyrKQ4gOyrxNH/La8wg9XLt4QzpBGkdp3eIS4cQj
# GulDc0scnMTSEYvluqJEcxbEEtK676GCF5cwgheTBgorBgEEAYI3AwMBMYIXgzCC
# F38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCJmScVTCqCvH5afWDuxLQoLiX9V2x0q8P4EhwO0hQytwIGZkY0h+XB
# GBMyMDI0MDYxNDEyMDkzNS4xMjZaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzcwMy0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHtMIIHIDCCBQigAwIBAgITMwAAAeqaJHLVWT9hYwABAAAB6jANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ1
# MzBaFw0yNTAzMDUxODQ1MzBaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzcwMy0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQC1C1/xSD8gB9X7Ludoo2rWb2ksqaF65QtJkbQpmsc6
# G4bg5MOv6WP/uJ4XOJvKX/c1t0ej4oWBqdGD6VbjXX4T0KfylTulrzKtgxnxZh7q
# 1uD0Dy/w5G0DJDPb6oxQrz6vMV2Z3y9ZxjfZqBnDfqGon/4VDHnZhdas22svSC5G
# HywsQ2J90MM7L4ecY8TnLI85kXXTVESb09txL2tHMYrB+KHCy08ds36an7IcOGfR
# mhHbFoPa5om9YGpVKS8xeT7EAwW7WbXL/lo5p9KRRIjAlsBBHD1TdGBucrGC3TQX
# STp9s7DjkvvNFuUa0BKsz6UiCLxJGQSZhd2iOJTEfJ1fxYk2nY6SCKsV+VmtV5ai
# PzY/sWoFY542+zzrAPr4elrvr9uB6ci/Kci//EOERZEUTBPXME/ia+t8jrT2y3ug
# 15MSCVuhOsNrmuZFwaRCrRED0yz4V9wlMTGHIJW55iNM3HPVJJ19vOSvrCP9lsEc
# EwWZIQ1FCyPOnkM1fs7880dahAa5UmPqMk5WEKxzDPVp081X5RQ6HGVUz6ZdgQ0j
# cT59EG+CKDPRD6mx8ovzIpS/r/wEHPKt5kOhYrjyQHXc9KHKTWfXpAVj1Syqt5X4
# nr+Mpeubv+N/PjQEPr0iYJDjSzJrqILhBs5pytb6vyR8HUVMp+mAA4rXjOw42vkH
# fQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFCuBRSWiUebpF0BU1MTIcosFblleMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQAog61WXj9+/nxVbX3G37KgvyoNAnuu2w3H
# oWZj3H0YCeQ3b9KSZThVThW4iFcHrKnhFMBbXJX4uQI53kOWSaWCaV3xCznpRt3c
# 4/gSn3dvO/1GP3MJkpJfgo56CgS9zLOiP31kfmpUdPqekZb4ivMR6LoPb5HNlq0W
# bBpzFbtsTjNrTyfqqcqAwc6r99Df2UQTqDa0vzwpA8CxiAg2KlbPyMwBOPcr9hJT
# 8sGpX/ZhLDh11dZcbUAzXHo1RJorSSftVa9hLWnzxGzEGafPUwLmoETihOGLqIQl
# Cpvr94Hiak0Gq0wY6lduUQjk/lxZ4EzAw/cGMek8J3QdiNS8u9ujYh1B7NLr6t3I
# glfScDV3bdVWet1itTUoKVRLIivRDwAT7dRH13Cq32j2JG5BYu/XitRE8cdzaJmD
# VBzYhlPl9QXvC+6qR8I6NIN/9914bTq/S4g6FF4f1dixUxE4qlfUPMixGr0Ft4/S
# 0P4fwmhs+WHRn62PB4j3zCHixKJCsRn9IR3ExBQKQdMi5auiqB6xQBADUf+F7hSK
# ZfbA8sFSFreLSqhvj+qUQF84NcxuaxpbJWVpsO18IL4Qbt45Cz/QMa7EmMGNn7a8
# MM3uTQOlQy0u6c/jq111i1JqMjayTceQZNMBMM5EMc5Dr5m3T4bDj9WTNLgP8SFe
# 3EqTaWVMOTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNQ
# MIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM3MDMtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCJ
# 2x7cQfjpRskJ8UGIctOCkmEkj6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6hZDkTAiGA8yMDI0MDYxNDA0MjAz
# M1oYDzIwMjQwNjE1MDQyMDMzWjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDqFkOR
# AgEAMAoCAQACAiX6AgH/MAcCAQACAhNrMAoCBQDqF5URAgEAMDYGCisGAQQBhFkK
# BAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJ
# KoZIhvcNAQELBQADggEBACX2Xpg/fj6GuFvJX7Lb5Q7N3TgbnatEuw0YYsIWmqY9
# LL0CMLT1SzuqsBUbui/2hvhf+x0KvWaF+qImrB4s2ECQYljmy8v3g3h5pXr2jyhq
# gCKNGz35jBxORCzusNdNW8zgw6iJ7ytMw4cct/9gowfIk8BOvlbs6gjgF5ZcbX2K
# jX5nQxXKZLVC3qFH0ZBpJf1p/nhJi5AzmqpOLJnRzJE7IYsAAIdksEt1ykt7Ixze
# DwyvFc6uypV9QaAKxUfPZEj4w5yVT0ZKwrL3XmyrKQoMhB/2NafUGeCUMXTn6RVE
# 95muAGcxSPHf7pA/3UwY07xlyqpXIXnI7RLG909HpkQxggQNMIIECQIBATCBkzB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAeqaJHLVWT9hYwABAAAB
# 6jANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCAkolQEmfm06CXOBueWeDDnJ2FlfpXUgBaXheb1Qzu5
# xTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EICmPodXjZDR4iwg0ltLANXBh
# 5G1uKqKIvq8sjKekuGZ4MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAHqmiRy1Vk/YWMAAQAAAeowIgQgM4t4I+DfcQ8fY2DpCXIiKjbx
# yGP2DRv+2mPQzaybBdEwDQYJKoZIhvcNAQELBQAEggIADkpFwzOeAAYJPNL4e/Tj
# 85kG5LOYEZ3zaeOc1/xYd7biHp6rHAgu18C86NiCL29yTy2tMBsyIKwadoayh3Ew
# AXygMLMXOa/Eme5tyHPxiE1tpJRXxUoPw1SJXuXtRPgZJwnNIR3Jfte72AF+K5T1
# AZOe+E/2rkqyAk1X/MIZXDNu9eq0xaurAu2dyuRAg8AAGuU/FoXbeLktPVjwhgob
# 1V+klfxKxu2qScweBHK+Ru3l+C265pRBUOnTDdfgFnCi6YJSqYtuaRbg9tv2ckLi
# 7fpSG68PtfkS2Ap01O4vVk9KTRvywSjQqbkJxbQurkgK18VB9+BiN+US/MAgQID7
# Fm7LqX3zWszL+GF/yM+irSTR0QOznocEjyQ/F/tQrqlczgmkIrOH/hP7/AXzD5cz
# vfFjFXl7DxNSnE/nQOhY6vkmsQX++WAn4x7Y15n9ax9dg6lsHPGqpT64BJgnjImC
# ftylBbqagjeeAc0iijt6MjY6N3ebOo1yoeTvaSW3eXYjHxHlOS8pd3cbCfO2qPoz
# SjLVAnr89MBBmZSC8KiULj6vP4v2RoM8Jw0TWMlElJicWqxFBf2nea131Zzgi59c
# +R6VLCLu1E5a/WO7oXxEYy/xlnkg6reOC+WuF8VutOaJ9splKUWvM6xOGjDUfvYt
# 780yo9gHHi42soJeAv/3/UE=
# SIG # End signature block
