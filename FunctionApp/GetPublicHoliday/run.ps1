<# The code above does the following, explained in English:
1. Read the query parameters from the request.
2. Read the body of the request.
3. Write to the Azure Functions log stream.
4. Interact with query parameters or the body of the request.
5. Associate values to output bindings by calling 'Push-OutputBinding'. 
https://luke.geek.nz/ #>

using namespace System.Net

# Input bindings are passed in via param block.
param([Parameter(Mandatory = $true)]$Request, [Parameter(Mandatory = $true)]$TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host 'GetPublicHoliday function processed a request.'


# Interact with query parameters or the body of the request.
$date = $Request.Query.Date
$country = $Request.Query.CountryCode

$resourceGroupName = $env:PublicHolidayRESOURCEGROUPNAME
$storageAccountName = $env:PublicHolidaySTORAGEACCNAME
$tableName = 'PublicHolidays'

$ClientIP = $Request.Headers."x-forwarded-for".Split(":")[0]


try {   
    
  $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
  $storageContext = $storageAccount.Context
  $cloudTable = (Get-AzStorageTable -Name $tableName -Context $storageContext).CloudTable

  Import-Module AzTable
   
  $Tables = Get-AzTableRow -table $cloudTable 
  Write-Host $Tables


  ForEach ($table in $Tables)
  {


    [string]$Filter1 = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("Country", [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal, $country)
    [string]$Filter2 = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("Date", [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal, $date)
    [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($Filter1, "and", $Filter2)     
    $object = Get-AzTableRow -table $cloudTable -CustomFilter $finalFilter
   Write-Host      $object
   
    $body = @()
     
    $System = New-Object -TypeName PSObject
    Add-Member -InputObject $System -MemberType NoteProperty -Name CountryCode -Value   $object.Country
    Add-Member -InputObject $System -MemberType NoteProperty -Name HolidayDate -Value   $object.Date
    Add-Member -InputObject $System -MemberType NoteProperty -Name HolidayYear -Value   $object.Year
    Add-Member -InputObject $System -MemberType NoteProperty -Name HolidayName -Value   $object.Name
    Add-Member -InputObject $System -MemberType NoteProperty -Name HolidayType -Value   $object.Type
    Add-Member -InputObject $System -MemberType NoteProperty -Name Comments -Value      $object.Comments
    Add-Member -InputObject $System -MemberType NoteProperty -Name RequestedIP -Value   $ClientIP

    $body += $System
    $System = New-Object -TypeName PSObject
     
    $status = [Net.HttpStatusCode]::OK

  }
  

}
catch {
  $body = "Failure connecting to table for state data, $_"
  $status = [Net.HttpStatusCode]::BadRequest
}
#$body =  $TriggerMetadata


# Associate values to output bindings by calling Push-OutputBinding'
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body       = $body
  }
)
