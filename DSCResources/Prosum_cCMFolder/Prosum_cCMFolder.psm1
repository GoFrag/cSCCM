######################################################################################
# The Get-TargetResource cmdlet.
# This function will get the collection if it exists and return all information
######################################################################################
function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$FolderName,
        
        [parameter(Mandatory = $true)]
        [validateset("2","7","9","14","17","18","19","20","23","25","2011","5000","5001","6000","6001")]
        [System.String]
		$FolderType,
        
        [parameter(Mandatory = $true)]
        [PSCredential]
        $SCCMAdministratorCredential
	)
    
    #Login
    ($oldToken, $context, $newToken) = ImpersonateAs -cred $SCCMAdministratorCredential

	#Load Module if missing then set the location for execution
    if(!(Get-Module ConfigurationManager)) {
        Try {
            Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
            }
        Catch {
            Throw "Cannot load the SCCM Module, please ensure the SCCM Admin tools are installed and try again"
            }
        }
    $ComputerInfo = Get-WmiObject Win32_ComputerSystem
    $ComputerFQDN = $ComputerInfo.Name + '.' + $ComputerInfo.Domain
    $CM12ProviderLocation = Get-WmiObject -Query "Select * From SMS_ProviderLocation where ProviderForLocalSite = True" -Namespace "root\sms" -computername $ComputerFQDN
    $Site = $CM12ProviderLocation.SiteCode
    if(!((Get-PSDrive) -like $Site)) {
        throw "Problems discovering a valid Site.  Please Investigate."
        }
    $OriginalLocation = Get-Location
    Set-Location ${Site}:

    #Get Folder Information	
    $CurrentFolder = Get-WmiObject -Class SMS_ObjectContainerNode -Namespace Root\SMS\Site_$Site | where-object {$_.Name -eq $FolderName -and $_.ObjectType -eq $FolderType}

    #Translate ParentContainerNodeID to ParentFolder
    $CurrentParentFolderID = $CurrentFolder.ParentContainerNodeID
    if($CurrentParentFolderID -eq "0") {
        $CurrentParentFolder ="Root"
        }
    else {
        $CurrentParentFolder = (Get-WmiObject -Class SMS_ObjectContainerNode -Namespace Root\SMS\Site_$Site -filter "ContainerNodeID='$CurrentParentFolderID'").Name
        }
    
	$ReturnValue = @{
		FolderName = $CurrentFolder.Name
		FolderType = if($CurrentFolder.ObjectType -eq '2'){'Package'}
            elseif($CurrentFolder.ObjectType -eq '7'){'Query'}
            elseif($CurrentFolder.ObjectType -eq '9'){'Software Metering'}
            elseif($CurrentFolder.ObjectType -eq '14'){'Operating System Installers'}
            elseif($CurrentFolder.ObjectType -eq '17'){'State Migration'}
            elseif($CurrentFolder.ObjectType -eq '18'){'Image Package'}
            elseif($CurrentFolder.ObjectType -eq '19'){'Boot Image'}
            elseif($CurrentFolder.ObjectType -eq '20'){'Task Sequence'}
            elseif($CurrentFolder.ObjectType -eq '23'){'Driver Package'}
            elseif($CurrentFolder.ObjectType -eq '25'){'Driver'}
            elseif($CurrentFolder.ObjectType -eq '2011'){'Configuration Baseline'}
            elseif($CurrentFolder.ObjectType -eq '5000'){'Device Collection'}
            elseif($CurrentFolder.ObjectType -eq '5001'){'User Collection'}
            elseif($CurrentFolder.ObjectType -eq '6000'){'Application'}
            elseif($CurrentFolder.ObjectType -eq '6001'){'Configuration Item'}
            else{''}
		ParentFolder = $CurrentParentFolder
        Ensure = if($CurrentFolder){'Present'}else{'Absent'}
	    }
    
    #Logout
    Set-Location $OriginalLocation
    if ($context) {
            $context.Undo()
            $context.Dispose()
            CloseUserToken($newToken)
        }

	$ReturnValue	
}

######################################################################################
# The Set-TargetResource cmdlet.
# This function will pass the "apply" switch back to the validate function
######################################################################################
function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$FolderName,

        [parameter(Mandatory = $true)]		
        [ValidateSet("2","7","9","14","17","18","19","20","23","25","2011","5000","5001","6000","6001")]
		[System.String]
		$FolderType,
        
        [parameter(Mandatory = $true)]
        [PSCredential]
        $SCCMAdministratorCredential,

		[System.String]
		$ParentFolder,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)

	ValidateProperties @PSBoundParameters -Apply
}

######################################################################################
# The Test-TargetResource cmdlet.
# This function will only return a $true $false on compliance
######################################################################################
function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$FolderName,

		[parameter(Mandatory = $true)]
        [ValidateSet("2","7","9","14","17","18","19","20","23","25","2011","5000","5001","6000","6001")]
		[System.String]
		$FolderType,
        
        [parameter(Mandatory = $true)]
        [PSCredential]
        $SCCMAdministratorCredential,

		[System.String]
		$ParentFolder,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)

	ValidateProperties @PSBoundParameters
}

######################################################################################
# The ValidateProperties cmdlet.
# This function accepts an -apply flag and "does the work"
######################################################################################
function ValidateProperties
{
    param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$FolderName,

		[parameter(Mandatory = $true)]
        [ValidateSet("2","7","9","14","17","18","19","20","23","25","2011","5000","5001","6000","6001")]
		[System.String]
		$FolderType,
        
        [parameter(Mandatory = $true)]
        [PSCredential]
        $SCCMAdministratorCredential,

		[System.String]
		$ParentFolder,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = 'Present',

        [Switch]$Apply
	)
    #Set initial TestedOK value to true, whch will be called later to see if all variables are still valid
    [boolean]$TestedOK = $true

    #Login
    ($oldToken, $context, $newToken) = ImpersonateAs -cred $SCCMAdministratorCredential

    #Load Module if missing then set the location for execution
    if(!(Get-Module ConfigurationManager)) {
        Try {
            Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
            }
        Catch {
            Throw "Cannot load the SCCM Module, please ensure the SCCM Admin tools are installed and try again"
            }
        }
    $ComputerInfo = Get-WmiObject Win32_ComputerSystem
    $ComputerFQDN = $ComputerInfo.Name + '.' + $ComputerInfo.Domain
    $CM12ProviderLocation = Get-WmiObject -Query "Select * From SMS_ProviderLocation where ProviderForLocalSite = True" -Namespace "root\sms" -computername $ComputerFQDN
    $Site = $CM12ProviderLocation.SiteCode
    if(!((Get-PSDrive) -like $Site)) {
        throw "Problems discovering a valid Site.  Please Investigate."
        }

    $OriginalLocation = Get-Location
    Set-Location ${Site}:

    #Attempt to Get Existing Folder and it's ID
    $CurrentFolder = Get-WmiObject -Class SMS_ObjectContainerNode -Namespace Root\SMS\Site_$Site | where-object {$_.Name -eq $FolderName -and $_.ObjectType -eq $FolderType}
    $CurrentFolderID = $CurrentFolder.ContainerNodeID


    If($Ensure -eq 'Absent') {
       
        #Delete if Folder exists
        If($CurrentFolder) {
            If($Apply) {
                Try {
                    $CurrentFolder.Delete()
                    }
                Catch {
                    Throw "Failed to Delete Folder $CurrentFolder, please check to ensure it's empty."
                    }
                }
            else {
                [boolean]$TestedOK = $false
                }
            }
        }
    
    else {
        #Test if the current Parent FolderExists
        If($ParentFolder -and ($ParentFolder -ne 'Root')) {
            $CurrentParentFolder = Get-WmiObject -Class SMS_ObjectContainerNode -Namespace Root\SMS\Site_$Site | where-object {$_.Name -eq $ParentFolder -and $_.ObjectType -eq $FolderType}
            if (!($CurrentParentFolder)) {
                throw "The folder $ParentFolder cannot be found in Site $Site."
                }
            }
    
        #Grab the ParentFolderID
        if (!($ParentFolder) -or ($ParentFolder -eq 'Root')) {
		    $ParentFolderID = 0
            }
        else {
            $ParentFolderID = (Get-WmiObject -Class SMS_ObjectContainerNode -Namespace Root\SMS\Site_$Site | where-object {$_.Name -eq $ParentFolder -and $_.ObjectType -eq $FolderType}).ContainerNodeID
            }

        #Create theFolder if it doesn't exist
        if(!($CurrentFolder)) {
            if($apply) {
		        $Arguments = @{
		            Name = $FolderName;
		            ObjectType = $FolderType;
		            ParentContainerNodeID = $ParentFolderID
		            }
		        Write-Verbose -Message "Create folder $FolderName with parent folder $ParentFolderName"
		        Set-WmiInstance -Class SMS_ObjectContainerNode -Arguments $Arguments -Namespace Root\SMS\Site_$Site | Out-Null
                Start-Sleep 2
                }
            else {
                [boolean]$TestedOK = $false
                }
	        }
    
        #Move the Folder if it's in the wrong location
        ##Re-gather the variable as a previous command may change values
        $CurrentFolder = Get-WmiObject -Class SMS_ObjectContainerNode -Namespace Root\SMS\Site_$Site | where-object {$_.Name -eq $FolderName -and $_.ObjectType -eq $FolderType}

        #Translate ParentContainerNodeID to ParentFolder
        $CurrentParentFolderID = $CurrentFolder.ParentContainerNodeID
        if($CurrentParentFolderID -ne $ParentFolderID) {
            if($Apply) {
                $Arguments = @{
		            Name = $FolderName;
		            ObjectType = $FolderType;
		            ParentContainerNodeID = $ParentFolderID
		            }
                Set-WmiInstance -Class SMS_ObjectContainerNode -Arguments $Arguments -Namespace Root\SMS\Site_$Site | Out-Null
                }
            else {
                [boolean]$TestedOK = $false
                }
            }
        }

    #Logout
    Set-Location $OriginalLocation
    if ($context) {
            $context.Undo()
            $context.Dispose()
            CloseUserToken($newToken)
        }

    #Return a true/false if the apply switch wasn't set
    if(!($apply)){
        return $TestedOK
        }
}


######################################################################################
# The below functions are used for user impersonation
# There are 3 functions in total
######################################################################################
function Get-ImpersonatetLib
{
    if ($script:ImpersonateLib)
    {
        return $script:ImpersonateLib
    }

    $sig = @'
[DllImport("advapi32.dll", SetLastError = true)]
public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);

[DllImport("kernel32.dll")]
public static extern Boolean CloseHandle(IntPtr hObject);
'@ 
   $script:ImpersonateLib = Add-Type -PassThru -Namespace 'Lib.Impersonation' -Name ImpersonationLib -MemberDefinition $sig 

   return $script:ImpersonateLib
    
}

function ImpersonateAs([PSCredential] $cred)
{
    [IntPtr] $userToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token
    $userToken
    $ImpersonateLib = Get-ImpersonatetLib

    $bLogin = $ImpersonateLib::LogonUser($cred.GetNetworkCredential().UserName, $cred.GetNetworkCredential().Domain, $cred.GetNetworkCredential().Password, 
    9, 0, [ref]$userToken)
    
    if ($bLogin)
    {
        $Identity = New-Object Security.Principal.WindowsIdentity $userToken
        $context = $Identity.Impersonate()
    }
    else
    {
        throw "Can't Logon as User $cred.GetNetworkCredential().UserName."
    }
    $context, $userToken
}

function CloseUserToken([IntPtr] $token)
{
    $ImpersonateLib = Get-ImpersonatetLib

    $bLogin = $ImpersonateLib::CloseHandle($token)
    if (!$bLogin)
    {
        throw "Can't close token"
    }
}


Export-ModuleMember -Function *-TargetResource
