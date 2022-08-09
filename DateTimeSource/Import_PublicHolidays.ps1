# https://luke.geek.nz/
$Folder = 'C:\Temp\API\'
$storageAccountName = 'funcnzpublicholidaystgac'
$resourceGroupName = 'rg-nzPublicHolidays-prd-ae'

#Downloads Pubic Holidays as CSV

$Csv = Import-csv "$Folder\DateTimeSource\SourceTimeDate.csv"

$CurrentYear = (Get-Date).Year


   ForEach ($Country in $Csv)
  {
$CountryCode = $Country.Country
Invoke-WebRequest -Uri "https://date.nager.at/PublicHoliday/Country/$CountryCode/$CurrentYear/CSV" -OutFile "$FolderAPI\DateTimeSource\Country$CountryCode$CurrentYear.csv" 
}


# Imports Public Holiday into Azure Storage table

# Requires AzTable Module (not part of the normal Az cmdlets)

Install-Module -Name AzTable
Import-Module AzTable

#Imports data from CSV files into $GLobalHolidays variable
$GlobalHolidays = Get-ChildItem "$Folder\DateTimeSource\*.csv" | Foreach-Object {
  $basename = $_.BaseName
  import-csv $_ 
}

#Connect-AzAccount
#Connects to Azure Storage Account
$storageAccountName = 'funcnzpublicholidaystgac'
$resourceGroupName = 'rg-publicHolidays-prd-ae'
$tableName = 'PublicHolidays'
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageContext = $storageAccount.Context
$cloudTable = (Get-AzStorageTable -Name $tableName -Context $storageContext).CloudTable

  
#Imports CSV data into Azure Table
$counter = 0
ForEach ($Holiday in $GlobalHolidays)

{
  $Date = [DateTime]($Holiday.Date)
  $Dayofweek = $Date.DayOfWeek | Out-String
  $Year = $Date.Year
  $HolidayDate = Get-Date $Date -format "dd-MM-yyyy"

 Add-AzTableRow `
  -table $cloudTable `
  -partitionKey '1' `
  -rowKey ((++$counter)) -property @{"Date"=$HolidayDate;"Country"=$Holiday.CountryCode;"Type"=$Holiday.Type;"Name"=$Holiday.LocalName;"Day"=$Dayofweek;"Year"=$Year;"Comments"=$Holiday.Counties}

}

#$Tables =  Get-AzTableRow -table $cloudTable 