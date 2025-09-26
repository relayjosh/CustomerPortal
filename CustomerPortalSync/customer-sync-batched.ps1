param(
    [int]$BatchSize = 1000,  # Process 1000 customers at a time
    [switch]$FullSync = $true
)

Write-Host "=== CustomerPortal Batched Sync ===" -ForegroundColor Green
Write-Host "Started: $(Get-Date)" -ForegroundColor Green

$erpConnectionString = "Server=vmi1002374;Database=epds01;Integrated Security=True;TrustServerCertificate=True;"
$mirrorConnectionString = "Server=localhost\SQLEXPRESS;Database=CustomerPortalMirror;Integrated Security=True;TrustServerCertificate=True;"

try {
    # First, get total count
    $erpConnection = New-Object System.Data.SqlClient.SqlConnection($erpConnectionString)
    $erpConnection.Open()
    $countCmd = $erpConnection.CreateCommand()
    $countCmd.CommandText = "SELECT COUNT(*) FROM customer WHERE active = 1"
    $totalCustomers = $countCmd.ExecuteScalar()
    $erpConnection.Close()
    
    Write-Host "Total customers to sync: $totalCustomers" -ForegroundColor Green
    Write-Host "Processing in batches of $BatchSize..." -ForegroundColor Yellow
    
    # Clear existing data first
    $mirrorConnection = New-Object System.Data.SqlClient.SqlConnection($mirrorConnectionString)
    $mirrorConnection.Open()
    $deleteCmd = $mirrorConnection.CreateCommand()
    $deleteCmd.CommandText = "DELETE FROM customer"
    $deleted = $deleteCmd.ExecuteNonQuery()
    Write-Host "Cleared $deleted existing customers" -ForegroundColor Yellow
    $mirrorConnection.Close()
    
    # Process in batches
    $totalInserted = 0
    $offset = 0
    
    while ($offset -lt $totalCustomers) {
        Write-Host "`nProcessing batch starting at customer $($offset + 1)..." -ForegroundColor Cyan
        
        # Get batch from ERP
        $erpConnection = New-Object System.Data.SqlClient.SqlConnection($erpConnectionString)
        $erpConnection.Open()
        
        $erpCommand = $erpConnection.CreateCommand()
        $erpCommand.CommandText = @"
            SELECT cust_no, cust_name, cust_addr1, cust_city, cust_state, cust_zip, cust_phone, active 
            FROM customer 
            WHERE active = 1 
            ORDER BY cust_no
            OFFSET $offset ROWS
            FETCH NEXT $BatchSize ROWS ONLY
"@
        
        $reader = $erpCommand.ExecuteReader()
        $batchCustomers = @()
        
        while ($reader.Read()) {
            $batchCustomers += [PSCustomObject]@{
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
        
        Write-Host "  Retrieved $($batchCustomers.Count) customers from ERP" -ForegroundColor Green
        
        # Insert batch into mirror
        $mirrorConnection = New-Object System.Data.SqlClient.SqlConnection($mirrorConnectionString)
        $mirrorConnection.Open()
        
        $batchInserted = 0
        foreach ($customer in $batchCustomers) {
            $insertCommand = $mirrorConnection.CreateCommand()
            $insertCommand.CommandText = @"
                INSERT INTO customer (cust_no, cust_name, cust_addr1, cust_city, cust_state, cust_zip, cust_phone, active, sync_date)
                VALUES (@cust_no, @cust_name, @cust_addr1, @cust_city, @cust_state, @cust_zip, @cust_phone, @active, GETDATE())
"@
            
            $insertCommand.Parameters.AddWithValue("@cust_no", $customer.cust_no) | Out-Null
            $insertCommand.Parameters.AddWithValue("@cust_name", $customer.cust_name) | Out-Null
            $insertCommand.Parameters.AddWithValue("@cust_addr1", $customer.cust_addr1) | Out-Null
            $insertCommand.Parameters.AddWithValue("@cust_city", $customer.cust_city) | Out-Null
            $insertCommand.Parameters.AddWithValue("@cust_state", $customer.cust_state) | Out-Null
            $insertCommand.Parameters.AddWithValue("@cust_zip", $customer.cust_zip) | Out-Null
            $insertCommand.Parameters.AddWithValue("@cust_phone", $customer.cust_phone) | Out-Null
            $insertCommand.Parameters.AddWithValue("@active", $customer.active) | Out-Null
            
            $insertCommand.ExecuteNonQuery() | Out-Null
            $batchInserted++
        }
        
        $mirrorConnection.Close()
        
        $totalInserted += $batchInserted
        $offset += $BatchSize
        
        Write-Host "  Inserted $batchInserted customers. Total: $totalInserted / $totalCustomers" -ForegroundColor Green
        Write-Host "  Progress: $([math]::Round(($totalInserted / $totalCustomers) * 100, 1))%" -ForegroundColor Cyan
    }
    
    Write-Host "`n=== FULL SYNC COMPLETED ===" -ForegroundColor Green
    Write-Host "Total customers synced: $totalInserted" -ForegroundColor Green
    Write-Host "Finished: $(Get-Date)" -ForegroundColor Green
    
} catch {
    Write-Host "`nSYNC FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to exit"