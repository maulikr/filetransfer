# Import the Microsoft Graph Module
Import-Module Microsoft.Graph

# Authenticate with Microsoft Graph
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"

# Ask the user for the group filter input
$keyword = Read-Host "Please enter the group filter (e.g., 'Azure')"

# Header of the output
Write-Output "MainGroupname;SubGroupName;UserName"

# Function to recursively fetch group members with sub-groups
function Get-GroupMembersWithSubGroups {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupId,
        [string]$ParentGroupName
    )
    
    try {
        # Fetch the group details
        $group = Get-MgGroup -GroupId $GroupId -ErrorAction Stop
        
        # Ensure group details are fetched correctly
        if ($null -eq $group) {
            Write-Output "Failed to fetch details for group ID: $GroupId"
            return
        }
        
        # Retrieve the group display name
        $groupName = $group.DisplayName
        $hasMembers = $false
        
        # Retrieve members of the Group
        $members = Get-MgGroupMember -GroupId $GroupId -All -ErrorAction Stop
        
        if ($members.Count -eq 0) {
            # If no members, print the group as empty
            Write-Output "$ParentGroupName;N/A;N/A"
        }
        
        $members | ForEach-Object {
            if ($_.AdditionalProperties.ContainsKey("userPrincipalName")) {
                # Direct user member, no sub-groups
                $userPrincipalName = $_.AdditionalProperties["userPrincipalName"]
                Write-Output "$ParentGroupName;N/A;$userPrincipalName"
                $hasMembers = $true
            } elseif ($_.AdditionalProperties.ContainsKey("displayName")) {
                # Sub-group member, fetch sub-group members
                $subGroupId = $_.Id
                $subGroupName = $_.AdditionalProperties["displayName"]
                $hasMembers = $true
                if ($subGroupName -like "*$keyword*") {
                    Get-SubGroupMembers -subGroupId $subGroupId -ParentGroupName $ParentGroupName -SubGroupName $subGroupName
                }
            }
        }
        
        # If the group has no direct members or sub-groups listed, indicate that it is empty
        if (-not $hasMembers) {
            Write-Output "$ParentGroupName;N/A;N/A"
        }
    } catch {
        Write-Output "Error fetching data for group ID: $GroupId - $_"
    }
}

# Function to fetch members of a sub-group
function Get-SubGroupMembers {
    param (
        [string]$subGroupId,
        [string]$ParentGroupName,
        [string]$SubGroupName
    )
    
    try {
        # Retrieve members of the sub-group
        $subGroupMembers = Get-MgGroupMember -GroupId $subGroupId -All -ErrorAction Stop
        
        if ($subGroupMembers.Count -eq 0) {
            # If no members, print the sub-group as empty
            Write-Output "$ParentGroupName;$SubGroupName;N/A"
        }
        
        $subGroupMembers | ForEach-Object {
            if ($_.AdditionalProperties.ContainsKey("userPrincipalName")) {
                $userPrincipalName = $_.AdditionalProperties["userPrincipalName"]
                Write-Output "$ParentGroupName;$SubGroupName;$userPrincipalName"
            }
        }
    } catch {
        Write-Output "Error fetching data for sub-group ID: $subGroupId - $_"
    }
}

# Retrieve all groups
Write-Host "Retrieving all groups..."
$allGroups = Get-MgGroup -All -ErrorAction Stop

# Loop through each group and fetch members, including sub-groups with keyword match
$allGroups | ForEach-Object {
    $groupId = $_.Id
    $groupName = $_.DisplayName
    if ($groupName -like "*$keyword*" -or ($_.AdditionalProperties.ContainsKey("displayName") -and $_.AdditionalProperties["displayName"] -like "*$keyword*")) {
        Get-GroupMembersWithSubGroups -GroupId $groupId -ParentGroupName $groupName
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
