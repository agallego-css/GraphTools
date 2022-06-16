# Powershell Graph tools
Powershell Graph tools mostly use in Exchange Online (Office 365) and AzureAD  

1. [Remove-GraphUserCalendarEvents](#remove-graphusercalendarevents)
2. [Export-GraphUserCalendarEvents](#export-graphusercalendarevents)
2. [Send-GraphMailMessage](#send-graphmailmessage)

## Remove-GraphUserCalendarEvents
Script to delete meeting items using Graph via Powershell.  
It can run on a single mailbox, or multiple mailboxes.  

[More Info](/Remove-GraphUserCalendarEvents/) - [Download (Right click and select 'Save link as')](https://raw.githubusercontent.com/agallego-css/Graphtools/master/Remove-GraphUserCalendarEvents/Remove-GraphUserCalendarEvents.ps1)  

----

## Export-GraphUserCalendarEvents
Script to export calendar items to CSV using Graph via Powershell.
It can run on a single mailbox, or multiple mailboxes.  

The report exports the following columns:  
> Subject, Organizer, Attendees, Location, Start Time, End Time, Type, ItemId  

[More info](/Export-GraphUserCalendarEvents/) - [Download (Right click and select 'Save link as')](https://raw.githubusercontent.com/agallego-css/Graphtools/master/Export-GraphUserCalendarEvents/Export-GraphUserCalendarEvents.ps1)  

----

## Send-GraphMailMessage

Script to send email messages through MS Graph using Powershell.

[More Info](/Send-GraphMailMessage/) - [Download (Right click and select 'Save link as')](https://raw.githubusercontent.com/agallego-css/Graphtools/master/send-GraphMailMessage/Send-GraphMailMessage.ps1)