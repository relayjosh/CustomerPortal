Write-Host "CustomerPortal PowerShell Sync Started: $(Get-Date)"

try {
    # Test ERP connection
    Write-Host "Testing ERP database connection..."
    $erpConnection = New-Object System.Data.SqlClient.SqlConnection
    $erpConnection.ConnectionString = "Server=vmi1002374;Database=epds01;Integrated Security=True;TrustServerCertificate=True;"
    $erpConnection.Open()
    
    $erpCommand = $erpConnection.CreateCommand()
    $erpCommand.CommandText = "SELECT COUNT(*) FROM customer WHERE active = 1"
    $erpResult = $erpCommand.ExecuteScalar()
    Write-Host "ERP Connection OK - Found $erpResult active customers"
    $erpConnection.Close()
    
    # Test Mirror connection
    Write-Host "Testing Mirror database connection..."
    $mirrorConnection = New-Object System.Data.SqlClient.SqlConnection
    $mirrorConnection.ConnectionString = "Server=localhost\SQLEXPRESS;Database=CustomerPortalMirror;Integrated Security=True;TrustServerCertificate=True;"
    $mirrorConnection.Open()
    
    $mirrorCommand = $mirrorConnection.CreateCommand()
    $mirrorCommand.CommandText = "SELECT COUNT(*) FROM customer"
    $mirrorResult = $mirrorCommand.ExecuteScalar()
    Write-Host "Mirror Connection OK - Currently has $mirrorResult customers"
    $mirrorConnection.Close()
    
    Write-Host "Both connections successful! PowerShell approach works."
    
} catch {
    Write-Host "Connection failed: $($_.Exception.Message)"
}

Read-Host "Press Enter to exit"