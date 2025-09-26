param(
    [int]$MaxCustomers = 100,  # Limit for testing
    [switch]$FullSync = $false
)

Write-Host "=== CustomerPortal Data Sync ===" -ForegroundColor Green
Write-Host "Started: $(Get-Date)" -ForegroundColor Green

$erpConnectionString = "Server=vmi1002374;Database=epds01;Integrated Security=True;TrustServerCertificate=True;"
$mirrorConnectionString = "Server=localhost\SQLEXPRESS;Database=CustomerPortalMirror;Integrated Security=True;TrustServerCertificate=True;"

try {
    Write-Host "`nSyncing customers..." -ForegroundColor Yellow
    
    # Get customer data from ERP
    $erpConnection = New-Object System.Data.SqlClient.SqlConnection($erpConnectionString)
    $erpConnection.Open()
    
    $limit = if ($FullSync) { "" } else { "TOP $MaxCustomers" }
    $erpCommand = $erpConnection.CreateCommand()
    $erpCommand.CommandText = @"
        SELECT $limit cust_no, cust_name, cust_addr1, cust_city, cust_state, cust_zip, cust_phone, active 
        FROM customer 
        WHERE active = 1 
        ORDER BY cust_no
"@
    
    $reader = $erpCommand.ExecuteReader()
    $customers = @()
    
    while ($reader.Read()) {
        $customers += [PSCustomObject]@{
            cust_no = $reader["cust_no"].ToString().Trim()
            cust_name = $reader["cust_name"].ToString().Trim()
            cust_addr1 = $reader["cust_addr1"].ToString().Trim()
            cust_city = $reader["cust_city"].ToString().Trim()
            cust_state = $reader["cust_state"].ToString().Trim()
            cust_zip = $reader["cust_zip"].ToString().Trim()
            cust_phone = $reader["cust_phone"].ToString().Trim()
            active = [bool]$reader["active"]
        }
    }
    
    $reader.Close()
    $erpConnection.Close()
    
    Write-Host "Retrieved $($customers.Count) customers from ERP" -ForegroundColor Green
    
    # Sync to mirror database
    $mirrorConnection = New-Object System.Data.SqlClient.SqlConnection($mirrorConnectionString)
    $mirrorConnection.Open()
    
    # Clear existing data (full refresh approach)
    $deleteCommand = $mirrorConnection.CreateCommand()
    $deleteCommand.CommandText = "DELETE FROM customer"
    $deleted = $deleteCommand.ExecuteNonQuery()
    Write-Host "Cleared $deleted existing records" -ForegroundColor Yellow
    
    # Insert new data
    $inserted = 0
    foreach ($customer in $customers) {
        $insertCommand = $mirrorConnection.CreateCommand()
        $insertCommand.CommandText = @"
            INSERT INTO customer (cust_no, cust_name, cust_addr1, cust_city, cust_state, cust_zip, cust_phone, active, sync_date)
            VALUES (@cust_no, @cust_name, @cust_addr1, @cust_city, @cust_state, @cust_zip, @cust_phone, @active, GETDATE())
"@
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_no", $customer.cust_no))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_name", $customer.cust_name))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_addr1", $customer.cust_addr1))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_city", $customer.cust_city))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_state", $customer.cust_state))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_zip", $customer.cust_zip))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_phone", $customer.cust_phone))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@active", $customer.active))) | Out-Null
        
        $insertCommand.ExecuteNonQuery() | Out-Null
        $inserted++
        
        if ($inserted % 50 -eq 0) {
            Write-Host "  Inserted $inserted customers..." -ForegroundColor Cyan
        }
    }
    
    $mirrorConnection.Close()
    
    Write-Host "`n=== SYNC COMPLETED ===" -ForegroundColor Green
    Write-Host "Inserted $inserted customers into mirror database" -ForegroundColor Green
    Write-Host "Finished: $(Get-Date)" -ForegroundColor Green
    
} catch {
    Write-Host "`nSYNC FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
}

Read-Host "`nPress Enter to exit"