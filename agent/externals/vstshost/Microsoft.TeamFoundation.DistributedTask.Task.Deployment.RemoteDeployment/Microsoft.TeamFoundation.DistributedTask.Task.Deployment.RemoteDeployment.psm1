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
# MIIoVQYJKoZIhvcNAQcCoIIoRjCCKEICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDvZ3uXMKhqjxqP
# pD9BYnyXygrXbhnvSUzwcypxeAztfKCCDYUwggYDMIID66ADAgECAhMzAAADri01
# UchTj1UdAAAAAAOuMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwODU5WhcNMjQxMTE0MTkwODU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQD0IPymNjfDEKg+YyE6SjDvJwKW1+pieqTjAY0CnOHZ1Nj5irGjNZPMlQ4HfxXG
# yAVCZcEWE4x2sZgam872R1s0+TAelOtbqFmoW4suJHAYoTHhkznNVKpscm5fZ899
# QnReZv5WtWwbD8HAFXbPPStW2JKCqPcZ54Y6wbuWV9bKtKPImqbkMcTejTgEAj82
# 6GQc6/Th66Koka8cUIvz59e/IP04DGrh9wkq2jIFvQ8EDegw1B4KyJTIs76+hmpV
# M5SwBZjRs3liOQrierkNVo11WuujB3kBf2CbPoP9MlOyyezqkMIbTRj4OHeKlamd
# WaSFhwHLJRIQpfc8sLwOSIBBAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhx/vdKmXhwc4WiWXbsf0I53h8T8w
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwMTgzNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AGrJYDUS7s8o0yNprGXRXuAnRcHKxSjFmW4wclcUTYsQZkhnbMwthWM6cAYb/h2W
# 5GNKtlmj/y/CThe3y/o0EH2h+jwfU/9eJ0fK1ZO/2WD0xi777qU+a7l8KjMPdwjY
# 0tk9bYEGEZfYPRHy1AGPQVuZlG4i5ymJDsMrcIcqV8pxzsw/yk/O4y/nlOjHz4oV
# APU0br5t9tgD8E08GSDi3I6H57Ftod9w26h0MlQiOr10Xqhr5iPLS7SlQwj8HW37
# ybqsmjQpKhmWul6xiXSNGGm36GarHy4Q1egYlxhlUnk3ZKSr3QtWIo1GGL03hT57
# xzjL25fKiZQX/q+II8nuG5M0Qmjvl6Egltr4hZ3e3FQRzRHfLoNPq3ELpxbWdH8t
# Nuj0j/x9Crnfwbki8n57mJKI5JVWRWTSLmbTcDDLkTZlJLg9V1BIJwXGY3i2kR9i
# 5HsADL8YlW0gMWVSlKB1eiSlK6LmFi0rVH16dde+j5T/EaQtFz6qngN7d1lvO7uk
# 6rtX+MLKG4LDRsQgBTi6sIYiKntMjoYFHMPvI/OMUip5ljtLitVbkFGfagSqmbxK
# 7rJMhC8wiTzHanBg1Rrbff1niBbnFbbV4UDmYumjs1FIpFCazk6AADXxoKCo5TsO
# zSHqr9gHgGYQC2hMyX9MGLIpowYCURx3L7kUiGbOiMwaMIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGiYwghoiAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPvd
# 2aSF2Ep37PuCnFW7e2ox0cizuB8VazPk++vL6yf0MEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEA1lCYqjW+8749jnxGNE3GJASAtrNTjA322yRR
# +gyzq2P4mwTkT3tF0F6wHySTWM3JMrnn087pHz49MBz+KfSgUQCFMNxN2JxfJTgD
# iNigD6k2HLZT1Ws1Wf0QMJGJhhBfuwl5LcNOkKA+T0Q6LOalp6zmG51ZnZyN5O2G
# miSJI3E8HFLGLo73JIw+MFPOu94P8geikJ4KddcPjc0toF/MeuzIEvGhIWWV47dW
# NWVgA619ce1hM1l8rOseNRm4EbZM5eKa2HJIkqjODLMAXq1m/KSz7BbfPQpDV6mq
# RM+4/yHWLUst2tH4Nyveil9d1fmRP2LNCIt4onP7xS17wbAGE6GCF7AwghesBgor
# BgEEAYI3AwMBMYIXnDCCF5gGCSqGSIb3DQEHAqCCF4kwgheFAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCBr9mXD3a9S52vKgYhkYg82MTfW7xtOjClx
# V+a1nTB7RAIGZut9MVpPGBMyMDI0MTAwOTA4MTU0Mi42MjRaMASAAgH0oIHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2RjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf4wggcoMIIFEKADAgECAhMzAAAB/Big
# r8xpWoc6AAEAAAH8MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMB4XDTI0MDcyNTE4MzExNFoXDTI1MTAyMjE4MzExNFowgdMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jv
# c29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# p1DAKLxpbQcPVYPHlJHyW7W5lBZjJWWDjMfl5WyhuAylP/LDm2hb4ymUmSymV0EF
# RQcmM8BypwjhWP8F7x4iO88d+9GZ9MQmNh3jSDohhXXgf8rONEAyfCPVmJzM7yts
# urZ9xocbuEL7+P7EkIwoOuMFlTF2G/zuqx1E+wANslpPqPpb8PC56BQxgJCI1LOF
# 5lk3AePJ78OL3aw/NdlkvdVl3VgBSPX4Nawt3UgUofuPn/cp9vwKKBwuIWQEFZ83
# 7GXXITshd2Mfs6oYfxXEtmj2SBGEhxVs7xERuWGb0cK6afy7naKkbZI2v1UqsxuZ
# t94rn/ey2ynvunlx0R6/b6nNkC1rOTAfWlpsAj/QlzyM6uYTSxYZC2YWzLbbRl0l
# RtSz+4TdpUU/oAZSB+Y+s12Rqmgzi7RVxNcI2lm//sCEm6A63nCJCgYtM+LLe9pT
# shl/Wf8OOuPQRiA+stTsg89BOG9tblaz2kfeOkYf5hdH8phAbuOuDQfr6s5Ya6W+
# vZz6E0Zsenzi0OtMf5RCa2hADYVgUxD+grC8EptfWeVAWgYCaQFheNN/ZGNQMkk7
# 8V63yoPBffJEAu+B5xlTPYoijUdo9NXovJmoGXj6R8Tgso+QPaAGHKxCbHa1QL9A
# SMF3Os1jrogCHGiykfp1dKGnmA5wJT6Nx7BedlSDsAkCAwEAAaOCAUkwggFFMB0G
# A1UdDgQWBBSY8aUrsUazhxByH79dhiQCL/7QdjAfBgNVHSMEGDAWgBSfpxVdAF5i
# XYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENB
# JTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsF
# AAOCAgEAT7ss/ZAZ0bTaFsrsiJYd//LQ6ImKb9JZSKiRw9xs8hwk5Y/7zign9gGt
# weRChC2lJ8GVRHgrFkBxACjuuPprSz/UYX7n522JKcudnWuIeE1p30BZrqPTOnsc
# D98DZi6WNTAymnaS7it5qAgNInreAJbTU2cAosJoeXAHr50YgSGlmJM+cN6mYLAL
# 6TTFMtFYJrpK9TM5Ryh5eZmm6UTJnGg0jt1pF/2u8PSdz3dDy7DF7KDJad2qHxZO
# RvM3k9V8Yn3JI5YLPuLso2J5s3fpXyCVgR/hq86g5zjd9bRRyyiC8iLIm/N95q6H
# WVsCeySetrqfsDyYWStwL96hy7DIyLL5ih8YFMd0AdmvTRoylmADuKwE2TQCTvPn
# jnLk7ypJW29t17Yya4V+Jlz54sBnPU7kIeYZsvUT+YKgykP1QB+p+uUdRH6e79Va
# iz+iewWrIJZ4tXkDMmL21nh0j+58E1ecAYDvT6B4yFIeonxA/6Gl9Xs7JLciPCIC
# 6hGdliiEBpyYeUF0ohZFn7NKQu80IZ0jd511WA2bq6x9aUq/zFyf8Egw+dunUj1K
# tNoWpq7VuJqapckYsmvmmYHZXCjK1Eus7V1I+aXjrBYuqyM9QpeFZU4U01YG15uW
# wUCaj0uZlah/RGSYMd84y9DCqOpfeKE6PLMk7hLnhvcOQrnxP6kwggdxMIIFWaAD
# AgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3Nv
# ZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIy
# MjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5
# vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64
# NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhu
# je3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl
# 3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPg
# yY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I
# 5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2
# ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/
# TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy
# 16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y
# 1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6H
# XtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMB
# AAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQW
# BBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30B
# ATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYB
# BAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1Vffwq
# reEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27
# DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pv
# vinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9Ak
# vUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWK
# NsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2
# kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+
# c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep
# 8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+Dvk
# txW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1Zyvg
# DbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/
# 2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWTCCAkECAQEwggEBoYHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2RjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUATkEpJXOaqI2w
# fqBsw4NLVwqYqqqggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDANBgkqhkiG9w0BAQsFAAIFAOqwWH4wIhgPMjAyNDEwMDkwMTE4NTRaGA8yMDI0
# MTAxMDAxMTg1NFowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA6rBYfgIBADAKAgEA
# AgILGQIB/zAHAgEAAgITbzAKAgUA6rGp/gIBADA2BgorBgEEAYRZCgQCMSgwJjAM
# BgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEB
# CwUAA4IBAQAUNZS16iIPqWyMtPCmzQhNDNavxY4t3NMCnPBD5izwx3YlmOcEZw1L
# oFXONfJXE0itThmeidkFO/e8MW39GAyr8oojxfIFGcFJpcuF7dWTIClQMjpC72e9
# 8brorz0RkldunZotCpfqVmOY9dCdNMW5tiGln7qnJfid/CPUziOcCThJaB4zt9tQ
# iVBq0o3F19GSvkiIukFcsHAcFXJ3dABxH0SoutsfmVt3kDsmJsCznBwVxAOy95Wu
# xpYmg8VjIojD2n0dTlxIgZUfTGoe1SDEcb7YZmD64qM8/5+bB+0HhTSU+CrB3kfb
# HUv6NhLazUyRAMX69LQx9H6stnYo6iACMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAH8GKCvzGlahzoAAQAAAfwwDQYJYIZI
# AWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG
# 9w0BCQQxIgQgBP3oPMjFwsQQpgOpphuojkyZO15DE0383cNDxPFmK8MwgfoGCyqG
# SIb3DQEJEAIvMYHqMIHnMIHkMIG9BCCVQq+Qu+/h/BOVP4wweUwbHuCUhh+T7hq3
# d5MCaNEtYjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMz
# AAAB/Bigr8xpWoc6AAEAAAH8MCIEID0rPQ8rGGF68sqiBINfy06qJilrvEV/CKoR
# WAHwETCAMA0GCSqGSIb3DQEBCwUABIICACN7y+6Yh73USBmuEUx5o9xFQEjoznwi
# LxWFo2wc70eQOFRV8mhaE0CQ3IhWMUbujRbYMJ5A86IiSlDJUxxmfWTS2KhDY22H
# DvY01CvdqxtbYvPI2Xq1A7PSurV17sjtmEJYQhEKIXI5wnjcX+Eqn2yKV50QjLPw
# OgeRpBGfsl3Ts82EiTjOSvjIBWXF76YqPRYiEcmzEFl8ohMT0Vq3+z3TTMtpGvc5
# qVzL2LPLj9y7wXcGNGgy0X9TkQcsv/7UroS+ZZmMO1KHpN1wzjKY2Y/i0v5CX66I
# KM4MRnCupdMPOSjUuge3foImN24w86nh36BrWv2NQL1hhAW5t9d9QphCPc3Vc/2n
# q5qR2q8btGuYbW6Pvogqe96Co+qFC9s5kDGL2a5NFnMMUB44poSlDIZvDeI1O0qh
# z1BSYOFk7/QxIB+UXcO1yLgRRKMrssHN1hAsTwXuK9o9RGC9sdyfxx4/nJ2XOa95
# HwCf/7swuY0ScV74f1pUWI8Jk98KE94KGtOshWwrVQ+p6NuBqutRD5DkDjK55flY
# u0GDfRCsoy2wsPxFB1BB+wu22LotP2c0k5EJfNV9wA+89LvpWpq55J45rh1GIqTk
# 7vGu0ZwFHq8oeYcV7Xtz1nIwNfqVCgjmZWcF2yRNc/VsY+qUQjOcm6mIgk4bQLm3
# RUaSoHE3bfhQ
# SIG # End signature block
