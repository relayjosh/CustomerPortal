param(
    [int]$MaxOrders = 200,     # Limit for testing
    [switch]$FullSync = $false,
    [int]$DaysBack = 365       # How far back to sync orders
)

Write-Host "=== CustomerPortal Order Sync ===" -ForegroundColor Green
Write-Host "Started: $(Get-Date)" -ForegroundColor Green

$erpConnectionString = "Server=vmi1002374;Database=epds01;Integrated Security=True;TrustServerCertificate=True;"
$mirrorConnectionString = "Server=localhost\SQLEXPRESS;Database=CustomerPortalMirror;Integrated Security=True;TrustServerCertificate=True;"

try {
    Write-Host "`nSyncing order headers..." -ForegroundColor Yellow
    
    # Get order header data from ERP
    $erpConnection = New-Object System.Data.SqlClient.SqlConnection($erpConnectionString)
    $erpConnection.Open()
    
    $limit = if ($FullSync) { "" } else { "TOP $MaxOrders" }
    $dateFilter = "WHERE order_dt >= DATEADD(DAY, -$DaysBack, GETDATE())"
    
    $erpCommand = $erpConnection.CreateCommand()
    $erpCommand.CommandText = @"
        SELECT $limit order_no, ord_type, order_dt, cust_no, cust_po, buyer, 
               ship_via, ship_date, ship_no, inv_no, inv_date, status, 
               freight, tax_amt
        FROM ord_hedr 
        $dateFilter
        ORDER BY order_no DESC
"@
    
    $reader = $erpCommand.ExecuteReader()
    $orders = @()
    
    while ($reader.Read()) {
        $orders += [PSCustomObject]@{
            order_no = [int]$reader["order_no"]
            ord_type = $reader["ord_type"].ToString().Trim()
            order_dt = [datetime]$reader["order_dt"]
            cust_no = if ($reader["cust_no"] -eq [DBNull]::Value) { $null } else { $reader["cust_no"].ToString().Trim() }
            cust_po = if ($reader["cust_po"] -eq [DBNull]::Value) { $null } else { $reader["cust_po"].ToString().Trim() }
            buyer = if ($reader["buyer"] -eq [DBNull]::Value) { $null } else { $reader["buyer"].ToString().Trim() }
            ship_via = if ($reader["ship_via"] -eq [DBNull]::Value) { $null } else { $reader["ship_via"].ToString().Trim() }
            ship_date = if ($reader["ship_date"] -eq [DBNull]::Value) { $null } else { [datetime]$reader["ship_date"] }
            ship_no = if ($reader["ship_no"] -eq [DBNull]::Value) { $null } else { [int]$reader["ship_no"] }
            inv_no = if ($reader["inv_no"] -eq [DBNull]::Value) { $null } else { [int]$reader["inv_no"] }
            inv_date = if ($reader["inv_date"] -eq [DBNull]::Value) { $null } else { [datetime]$reader["inv_date"] }
            status = $reader["status"].ToString().Trim()
            freight = if ($reader["freight"] -eq [DBNull]::Value) { $null } else { [decimal]$reader["freight"] }
            tax_amt = if ($reader["tax_amt"] -eq [DBNull]::Value) { $null } else { [decimal]$reader["tax_amt"] }
        }
    }
    
    $reader.Close()
    $erpConnection.Close()
    
    Write-Host "Retrieved $($orders.Count) order headers from ERP" -ForegroundColor Green
    
    # Sync to mirror database
    $mirrorConnection = New-Object System.Data.SqlClient.SqlConnection($mirrorConnectionString)
    $mirrorConnection.Open()
    
    # Clear existing order data
    Write-Host "Clearing existing order data..." -ForegroundColor Yellow
    $deleteDetails = $mirrorConnection.CreateCommand()
    $deleteDetails.CommandText = "DELETE FROM ord_detl"
    $deletedDetails = $deleteDetails.ExecuteNonQuery()
    
    $deleteHeaders = $mirrorConnection.CreateCommand()
    $deleteHeaders.CommandText = "DELETE FROM ord_hedr"
    $deletedHeaders = $deleteHeaders.ExecuteNonQuery()
    
    Write-Host "Cleared $deletedHeaders order headers and $deletedDetails order details" -ForegroundColor Yellow
    
    # Insert order headers
    $inserted = 0
    foreach ($order in $orders) {
        $insertCommand = $mirrorConnection.CreateCommand()
        $insertCommand.CommandText = @"
            INSERT INTO ord_hedr (order_no, ord_type, order_dt, cust_no, cust_po, buyer,
                                 ship_via, ship_date, ship_no, inv_no, inv_date, status,
                                 freight, tax_amt, sync_date)
            VALUES (@order_no, @ord_type, @order_dt, @cust_no, @cust_po, @buyer,
                    @ship_via, @ship_date, @ship_no, @inv_no, @inv_date, @status,
                    @freight, @tax_amt, GETDATE())
"@
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@order_no", $order.order_no))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@ord_type", [System.Data.SqlDbType]::Char, 1))) | Out-Null
        $insertCommand.Parameters["@ord_type"].Value = if ($order.ord_type) { $order.ord_type } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@order_dt", $order.order_dt))) | Out-Null
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_no", [System.Data.SqlDbType]::Char, 6))) | Out-Null
        $insertCommand.Parameters["@cust_no"].Value = if ($order.cust_no) { $order.cust_no } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@cust_po", [System.Data.SqlDbType]::Char, 20))) | Out-Null
        $insertCommand.Parameters["@cust_po"].Value = if ($order.cust_po) { $order.cust_po } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@buyer", [System.Data.SqlDbType]::Char, 40))) | Out-Null
        $insertCommand.Parameters["@buyer"].Value = if ($order.buyer) { $order.buyer } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@ship_via", [System.Data.SqlDbType]::Char, 3))) | Out-Null
        $insertCommand.Parameters["@ship_via"].Value = if ($order.ship_via) { $order.ship_via } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@ship_date", [System.Data.SqlDbType]::DateTime))) | Out-Null
        $insertCommand.Parameters["@ship_date"].Value = if ($order.ship_date) { $order.ship_date } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@ship_no", [System.Data.SqlDbType]::SmallInt))) | Out-Null
        $insertCommand.Parameters["@ship_no"].Value = if ($order.ship_no) { $order.ship_no } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@inv_no", [System.Data.SqlDbType]::Int))) | Out-Null
        $insertCommand.Parameters["@inv_no"].Value = if ($order.inv_no) { $order.inv_no } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@inv_date", [System.Data.SqlDbType]::DateTime))) | Out-Null
        $insertCommand.Parameters["@inv_date"].Value = if ($order.inv_date) { $order.inv_date } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@status", [System.Data.SqlDbType]::Char, 1))) | Out-Null
        $insertCommand.Parameters["@status"].Value = $order.status
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@freight", [System.Data.SqlDbType]::Decimal))) | Out-Null
        $insertCommand.Parameters["@freight"].Value = if ($order.freight) { $order.freight } else { [DBNull]::Value }
        
        $insertCommand.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@tax_amt", [System.Data.SqlDbType]::Decimal))) | Out-Null
        $insertCommand.Parameters["@tax_amt"].Value = if ($order.tax_amt) { $order.tax_amt } else { [DBNull]::Value }
        
        $insertCommand.ExecuteNonQuery() | Out-Null
        $inserted++
        
        if ($inserted % 50 -eq 0) {
            Write-Host "  Inserted $inserted order headers..." -ForegroundColor Cyan
        }
    }
    
    $mirrorConnection.Close()
    
    Write-Host "`n=== ORDER SYNC COMPLETED ===" -ForegroundColor Green
    Write-Host "Inserted $inserted order headers into mirror database" -ForegroundColor Green
    Write-Host "Finished: $(Get-Date)" -ForegroundColor Green
    
} catch {
    Write-Host "`nORDER SYNC FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
}

Read-Host "`nPress Enter to exit"