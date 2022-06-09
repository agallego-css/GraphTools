﻿<#
    .SYNOPSIS
    Script to delete meeting items using Graph via Powershell.
    
    .DESCRIPTION
    Script to delete meeting items using Graph via Powershell.
    It can run on a single mailbox, or multiple mailboxes.

    If it runs on a single mailbox, the module can pop-up and request the authenticated user to consent Graph permissions. The script will run against the authenticated mailbox.
    If it runs against multiple mailboxes, an AzureAD Registered App is needed, with the appropriate Application permissions (requires 'Calendars.ReadWrite' API permission granted).

    If the event is a meeting, deleting the event on the organizer's calendar sends a cancellation message to the meeting attendees.
    
    .PARAMETER ClientID
    This is an optional parameter. String parameter with the ClientID (or AppId) of your AzureAD Registered App.
    
    .PARAMETER TenantID
    This is an optional parameter. String parameter with the TenantID your AzureAD tenant.
    
    .PARAMETER CertificateThumbprint
    This is an optional parameter. Certificate thumbprint which is uploaded to the AzureAD App.
    
    .PARAMETER Subject
    This is an mandatory parameter. The exact subject text to filter meeting items. This parameter cannot be used together with the "FromAddress" parameter.
    
    .PARAMETER FromAddress
    This is an mandatory parameter. The sender address to filter meeting items. This parameter cannot be used together with the "Subject" parameter.
    
    .PARAMETER Mailboxes
    This is an optional parameter. This is a list of SMTP Addresses. If this parameter is ommitted, the script will run against the authenticated user mailbox.
    
    .PARAMETER StartDate
    This is an optional parameter. The script will search for meeting items starting based on this StartDate onwards. If this parameter is ommitted, by default will consider the current date.
    
    .PARAMETER DisableTranscript
    This is an optional parameter. Transcript is enabled by default. Use this parameter to not write the powershell Transcript.
    
    .PARAMETER DisconnectMgGraph
    This is an optional parameter. Use this parameter to disconnect from MgGraph when it finishes.
    
    .EXAMPLE
    PS C:\> .\Remove-GraphUserCalendarEvents.ps1 -Subject "Yearly Team Meeting" -StartDate 06/20/2022 -Verbose
    The script will install required modules if not already installed.
    Later it will request the user credential, and ask for permissions consent if not granted already.
    Then it will search for all meeting items matching exact subject "Yearly Team Meeting" starting on 06/20/2022 forward.
    It will display the items found and proceed to remove them.

    .EXAMPLE
    PS C:\> $mailboxes = Get-Mailbox -Filter {Office -eq "Staff"} | Select-Object PrimarySMTPAddress
    PS C:\> .\Remove-GraphUserCalendarEvents.ps1 -Subject "Yearly Team Meeting" -Mailboxes $mailboxes -Verbose
    The script will install required modules if not already installed.
    Later it will connect to MgGraph using AzureAD App details (requires ClientID, TenantID and CertificateThumbprint).
    Then it will search for all meeting items matching exact subject "Yearly Team Meeting" starting on the current date forward, for all mailboxes belonging to the "Staff" Office.
    It will display the items found and proceed to remove them.

    .NOTES
    Author: Agustin Gallegos
    #>
[CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
param (
    [String] $ClientID = "766775a3-1e4c-43b9-bed1-def9e3ca22d3",

    [String] $TenantID = "ef494636-2282-44b5-8724-3c6a034994a0",

    [String] $CertificateThumbprint = "f938b339e43c2d6b97831d4d7131ce256c5b50e6",

    [parameter(ParameterSetName="Subject")]
    [String] $Subject,

    [parameter(ParameterSetName="FromAddress")]
    [String] $FromAddress,

    [String[]] $Mailboxes,

    [DateTime] $StartDate = (Get-date),

    [Switch] $DisableTranscript,

    [Switch] $DisconnectMgGraph
)
    
begin {
    if ( -not($DisableTranscript) ) {
        Start-Transcript
    }
    # Downloading required Graph modules
    if ( -not(Get-Module Microsoft.Graph.Users -ListAvailable)) {
        Write-Verbose "'Microsoft.Graph.Users' Module not found. Installing it..."
        Install-Module Microsoft.Graph.Users -Scope CurrentUser -Force
    }
    if ( -not(Get-Module Microsoft.Graph.Calendar -ListAvailable)) {
        Write-Verbose "'Microsoft.Graph.Calendar' Module not found. Installing it..."
        Install-Module Microsoft.Graph.Calendar -Scope CurrentUser -Force
    }
    if ( -not(Get-Module Microsoft.Graph.Authentication -ListAvailable)) {
        Write-Verbose "'Microsoft.Graph.Authentication' Module not found. Installing it..."
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
    }
    Import-Module Microsoft.Graph.Users, Microsoft.Graph.Calendar -Verbose:$false

    # Connect to Graph if there is no current context
    $conn = Get-MgContext
    if ( $null -eq $conn -or $conn.Scopes -notcontains "Calendars.ReadWrite" ) {
        Write-Verbose "There is currently no active connection to MgGraph or current connection is missing required 'Calendars.ReadWrite' Scope."
        if ( -not($PSBoundParameters.ContainsKey('Mailboxes')) ) {
            # Connecting to graph with the user account
            Write-Verbose "Connecting to graph with the user account"
            Connect-MgGraph -Scopes "Calendars.ReadWrite"
        }
        else {
            # Connecting to graph using Azure App
            if ( $clientID -eq $null -or $TenantID -eq $null -or $CertificateThumbprint -eq $null ) {
                Write-Host "Required 'ClientID', 'TenantID' and 'CertificateThumbprint' parameters are missing to connect using App Authentication."
                Exit
            }
            Write-Verbose "Connecting to graph with Azure AppId: $ClientID"
            Connect-MgGraph -ClientId $ClientID -TenantId $TenantID -CertificateThumbprint $CertificateThumbprint
        }
    }
    else {
        if ( $null -eq $conn.Account ){
            Write-Verbose "Currently connect with App Account: $($conn.AppName)"
        }
        else {
            Write-Verbose "Currently connected with User Account: $($conn.Account)"
        }
    }
    $mbxs = (Get-MgContext).Account
    if ( $PSBoundParameters.ContainsKey('Mailboxes') ) {
        $mbxs = $Mailboxes
    }
}

process {

    $i = 0
    foreach ( $mb in $mbxs ) {
        $events = New-Object System.Collections.ArrayList
        $i++
        Write-Progress -activity "Scanning Users: $i out of $($mbxs.Count)" -status "Percent scanned: " -PercentComplete ($i * 100 / $($mbxs.Count)) -ErrorAction SilentlyContinue
        Write-Verbose "Working on mailbox $mb"
        switch ($PSBoundParameters.Keys) {
            Subject {
                Write-Verbose "Collecting events based on exact subject: '$Subject'"
                $eventsFound = Get-MgUserEvent -UserId $mb -Filter "Subject eq '$subject'" -All
                foreach ($ev in $eventsFound) {
                    if ( [DateTime]$ev.Start.DateTime -gt $StartDate ) {
                        $null = $events.add($ev)
                    }
                }
            }
            FromAddress {
                Write-Verbose "Collecting events based on sender: '$FromAddress'"
                $eventsFound = Get-MgUserEvent -UserId $mb -all | Where-Object { $_.Organizer.EmailAddress.Address -eq "$FromAddress" } 
                foreach ($ev in $eventsFound) {
                    if ( [DateTime]$ev.Start.DateTime -gt $StartDate ) {
                        $null = $events.add($ev)
                    }
                }
            }
        }
        if ( $events.Count -eq 0 ) {
            Write-Verbose "No events found based on parameters criteria. Please double check and try again."
            Continue
        }
        # Exporting found events to Verbose deleting
        if ( $PSBoundParameters.ContainsKey('Verbose') ) {
            Write-Verbose "Displaying events details:"
            $events | Select-Object subject,@{N="Mailbox";E={$_.AdditionalProperties.'calendar@odata.navigationLink'.Split("'")[1]}},@{N="organizer";E={$_.Organizer.EmailAddress.Address}},@{N="Attendees";E={$_.Attendees | ForEach-Object {$_.EmailAddress.Address -join ";"}}},@{N="StartTime";E={$_.Start.DateTime}},@{N="EndTime";E={$_.End.DateTime}},id
        }
        foreach ( $event in $events ) {
            Write-Verbose "Removing event item from '$($event.Organizer.EmailAddress.Address)' with subject '$($event.Subject)' and item ID '$($event.id)'"
            Remove-MgUserEvent -UserId $mb -EventId $event.id
        }
    }
}

end {
    if ( -not($DisableTranscript) ) {
        Stop-Transcript
    }

    if ( $DisconnectMgGraph ) {
        Disconnect-MgGraph
    }
}