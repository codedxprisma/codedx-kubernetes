
'../powershell-algorithms/data-structures.ps1',
'../core/common/question.ps1',
'../core/common/utils.ps1'
 | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

enum ProviderType {
	Minikube
	Aks
	Eks
	Other
}

enum IngressType {
	None
	NginxLetsEncrypt
	ClassicElb
	NetworkElb
}

class ConfigInput {

	[bool]         $prereqsSatisified
	[string]       $missingPrereqs

	[string]       $workDir
	[ProviderType] $k8sProvider
	[string]       $kubeApiTargetPort
	[string]       $kubeContextName

	[string]       $codeDxDnsName

	[string]       $namespaceCodeDx
	[string]       $releaseNameCodeDx
	[string]       $namespaceToolOrchestration
	[string]       $releaseNameToolOrchestration

	[string]       $storageClassName

	[bool]         $useVolumeSizeDefaults
	[int]          $codeDxVolumeSizeGiB
	[int]          $dbVolumeSizeGiB
	[int]          $dbSlaveVolumeSizeGiB
	[int]          $minioVolumeSizeGiB

	[bool]         $useCPUDefaults
	[string]       $codeDxCPUReservation
	[string]       $dbMasterCPUReservation
	[string]       $dbSlaveCPUReservation
	[string]       $toolServiceCPUReservation
	[string]       $minioCPUReservation
	[string]       $workflowCPUReservation
	[string]       $nginxCPUReservation

	[bool]         $useMemoryDefaults
	[string]       $codeDxMemoryReservation
	[string]       $dbMasterMemoryReservation
	[string]       $dbSlaveMemoryReservation
	[string]       $toolServiceMemoryReservation
	[string]       $minioMemoryReservation
	[string]       $workflowMemoryReservation
	[string]       $nginxMemoryReservation

	[bool]         $useEphemeralStorageDefaults
	[string]       $codeDxEphemeralStorageReservation
	[string]       $dbMasterEphemeralStorageReservation
	[string]       $dbSlaveEphemeralStorageReservation
	[string]       $toolServiceEphemeralStorageReservation
	[string]       $minioEphemeralStorageReservation
	[string]       $workflowEphemeralStorageReservation
	[string]       $nginxEphemeralStorageReservation

	[bool]         $useDefaultDockerImages
	[string]       $imageCodeDxTomcat
	[string]       $imageCodeDxTools
	[string]       $imageCodeDxToolsMono
	[string]       $imageToolService
	[string]       $imageSendResults
	[string]       $imageSendErrorResults
	[string]       $imageNewAnalysis
	[string]       $imagePreDelete

	[int]          $toolServiceReplicas

	[bool]         $useDefaultOptions
	[bool]         $skipPSPs
	[bool]         $skipNetworkPolicies
	[bool]         $skipTLS

	[string]       $serviceTypeCodeDx
	[hashtable]    $serviceAnnotationsCodeDx

	[IngressType]  $ingressType
	[bool]         $skipNginxIngressControllerInstall
	[string]       $nginxIngressControllerLoadBalancerIP
	[string]       $nginxIngressControllerNamespace

	[bool]         $skipLetsEncryptCertManagerInstall
	[string]       $letsEncryptCertManagerRegistrationEmailAddress
	[string]       $letsEncryptCertManagerClusterIssuer
	[string]       $letsEncryptCertManagerNamespace

	[bool]         $skipIngressEnabled
	[bool]         $skipIngressAssumesNginx
	[hashtable]    $ingressAnnotationsCodeDx

	[string]       $toolServiceApiKey
      
	[string]       $codedxAdminPwd
	[string]       $minioAdminPwd
	[string]       $mariadbRootPwd
	[string]       $mariadbReplicatorPwd
	[int]          $dbSlaveReplicaCount
      
	[bool]         $skipToolOrchestration

	[bool]         $skipPrivateDockerRegistry
	[string]       $dockerImagePullSecretName
	[string]       $dockerRegistry
	[string]       $dockerRegistryUser
	[string]       $dockerRegistryPwd

	[bool]         $skipDatabase
	[string]       $externalDatabaseHost
	[int]          $externalDatabasePort
	[string]       $externalDatabaseName
	[string]       $externalDatabaseUser
	[string]       $externalDatabasePwd
	[bool]         $externalDatabaseSkipTls
	[string]       $externalDatabaseServerCert

	[bool]         $useDefaultCACerts
	[string]       $caCertsFilePath
	[string]       $caCertsFilePwd
	[bool]         $useNewCACertsFilePwd
	[string]       $caCertsFileNewPwd
	[bool]         $addExtraCertificates
	[string[]]     $extraCodeDxTrustedCaCertPaths

	[string]       $clusterCertificateAuthorityCertPath

	[bool]                   $useNodeSelectors
	[Tuple`2[string,string]] $codeDxNodeSelector
	[Tuple`2[string,string]] $masterDatabaseNodeSelector
	[Tuple`2[string,string]] $subordinateDatabaseNodeSelector
	[Tuple`2[string,string]] $toolServiceNodeSelector
	[Tuple`2[string,string]] $minioNodeSelector
	[Tuple`2[string,string]] $workflowControllerNodeSelector

	[bool]                   $useTolerations
	[Tuple`2[string,string]] $codeDxNoScheduleExecuteToleration
	[Tuple`2[string,string]] $masterDatabaseNoScheduleExecuteToleration
	[Tuple`2[string,string]] $subordinateDatabaseNoScheduleExecuteToleration
	[Tuple`2[string,string]] $toolServiceNoScheduleExecuteToleration
	[Tuple`2[string,string]] $minioNoScheduleExecuteToleration
	[Tuple`2[string,string]] $workflowControllerNoScheduleExecuteToleration

	[hashtable]  $notes = @{}

	[bool]HasContext() {
		return $this.kubeContextName -ne ''
	}
}

class Step : GraphVertex {

	[string]      $name
	[ConfigInput] $config

	[string]      $title
	[string]      $message
	[string]      $prompt

	Step([string]      $name, 
		 [ConfigInput] $config,
		 [string]      $title,
		 [string]      $message,
		 [string]      $prompt) : base($name) {

		$this.name = $name
		$this.config = $config
		$this.title = $title
		$this.message = $message
		$this.prompt = $prompt
	}

	[bool]CanRun() {
		return $true
	}

	[bool]Run() {

		Write-HostSection $this.title ($this.GetMessage())

		while ($true) {
			$question = $this.MakeQuestion($this.prompt)
			$question.Prompt()
			
			if (-not $question.hasResponse) {
				return $false
			}
	
			if ($this.HandleResponse($question)) {
				break
			}
		}
		return $true
	}

	[IQuestion]MakeQuestion([string]$prompt) {
		return new-object Question($prompt)
	}

	[bool]HandleResponse([IQuestion] $question) {
		throw [NotImplementedException]
	}

	[string]GetMessage() {
		return $this.message
	}

	[void]Reset() {
		
	}

	[void]ApplyDefault() {
		throw [NotImplementedException]
	}

	[string]GetDefault() {
		return ''
	}

	[void]Delay() {
		Start-Sleep -Seconds 1
	}

	[object]toString() {
		return $this.name
	}
}

function Write-StepGraph([string] $path, [hashtable] $steps, [collections.stack] $stepsVisited) {

	"# Enter graph at https://dreampuf.github.io/GraphvizOnline (select 'dot' Engine and use Format 'png-image-element')`ndigraph G {`n" | out-file $path -force

	$linksVisited = New-Object Collections.Generic.HashSet[string]
	
	$previousStep = $null
	while ($stepsVisited.count -gt 0) {

		$step = $stepsVisited.pop()
		"$step [color=blue];" | out-file $path -append

		if ($null -eq $previousStep) {
			$previousStep = $step
			continue
		}
		
		$link = "$step -> $previousStep"
		"$link [color=blue];" | out-file $path -append

		$linksVisited.add($link) | out-null
		$previousStep = $step
	}

	$steps.keys | ForEach-Object {
		$node = $steps[$_]
		$node.getNeighbors() | ForEach-Object {
			$link = "$node -> $_"
			if (-not $linksVisited.Contains($link)) {
				"$link;" | out-file $path -append
			}
		}
	}

	"}" | out-file $path -append
}
